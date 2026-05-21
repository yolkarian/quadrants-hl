#include "bindings/hashlink/native/descriptor.h"
#include "bindings/hashlink/native/descriptor_internal.h"

#include <algorithm>
#include <array>
#include <cstring>
#include <limits>
#include <optional>
#include <variant>
#include <stdexcept>
#include <utility>

#include "quadrants/compilation_manager/kernel_compilation_manager.h"
#include "quadrants/ir/frontend_ir.h"
#include "quadrants/ir/expr.h"
#include "quadrants/ir/type.h"
#include "quadrants/program/kernel.h"
#include "quadrants/program/program.h"

namespace quadrants::hashlink {
namespace {

constexpr std::size_t kHeaderSize = 20;
constexpr std::uint32_t kMagic = 0x4c484451;  // "QDHL", little-endian.
constexpr std::uint32_t kVersion = 2;
constexpr std::uint32_t kUnknownSize = std::numeric_limits<std::uint32_t>::max();

class DescriptorReader {
 public:
  DescriptorReader(const std::uint8_t *data, std::size_t size) : data_(data), size_(size) {
    if (data == nullptr) {
      throw std::runtime_error("HashLink kernel descriptor is null");
    }
  }

  void seek(std::size_t pos) {
    if (pos > size_) {
      throw std::runtime_error("HashLink kernel descriptor offset is out of range");
    }
    pos_ = pos;
  }

  std::size_t pos() const {
    return pos_;
  }

  std::size_t remaining() const {
    return size_ - pos_;
  }

  std::uint8_t read_u8() {
    require(1);
    return data_[pos_++];
  }

  std::uint32_t read_u32() {
    require(4);
    const std::uint32_t value = static_cast<std::uint32_t>(data_[pos_]) |
                                (static_cast<std::uint32_t>(data_[pos_ + 1]) << 8) |
                                (static_cast<std::uint32_t>(data_[pos_ + 2]) << 16) |
                                (static_cast<std::uint32_t>(data_[pos_ + 3]) << 24);
    pos_ += 4;
    return value;
  }

  std::int32_t read_i32() {
    return static_cast<std::int32_t>(read_u32());
  }

  std::uint64_t read_u64() {
    const std::uint64_t low = read_u32();
    const std::uint64_t high = read_u32();
    return low | (high << 32);
  }

  std::int64_t read_i64() {
    return static_cast<std::int64_t>(read_u64());
  }

  float read_f32() {
    const std::uint32_t bits = read_u32();
    float value = 0.0f;
    static_assert(sizeof(value) == sizeof(bits));
    std::memcpy(&value, &bits, sizeof(value));
    return value;
  }

  double read_f64() {
    const std::uint64_t low = read_u32();
    const std::uint64_t high = read_u32();
    const std::uint64_t bits = low | (high << 32);
    double value = 0.0;
    static_assert(sizeof(value) == sizeof(bits));
    std::memcpy(&value, &bits, sizeof(value));
    return value;
  }

  std::string read_string(std::uint32_t len) {
    require(len);
    const char *begin = reinterpret_cast<const char *>(data_ + pos_);
    pos_ += len;
    return std::string(begin, begin + len);
  }

 private:
  void require(std::size_t count) const {
    if (count > size_ || pos_ > size_ - count) {
      throw std::runtime_error("HashLink kernel descriptor is truncated");
    }
  }

  const std::uint8_t *data_{nullptr};
  std::size_t size_{0};
  std::size_t pos_{0};
};

std::string checked_string(const KernelDescriptor &descriptor, std::uint32_t id, const char *what) {
  if (id >= descriptor.strings.size()) {
    throw std::runtime_error(std::string("HashLink kernel descriptor has invalid ") + what + " string id");
  }
  return descriptor.strings[id];
}

lang::DebugInfo make_debug_info(const KernelDescriptor &descriptor) {
  lang::DebugInfo info;
  if (descriptor.source_spans.empty()) {
    return info;
  }
  const auto &span = descriptor.source_spans.front();
  const std::string file = checked_string(descriptor, span.file_name_id, "source span file");
  info.src_loc.line_number = static_cast<int>(span.line);
  info.src_loc.var_name = file;
  info.tb = file;
  if (span.line != 0) {
    info.tb += ":" + std::to_string(span.line);
  } else {
    info.tb += "@" + std::to_string(span.begin);
  }
  info.tb += ": ";
  return info;
}

void require_section_entries_fit(std::size_t pos,
                                 std::size_t end,
                                 std::uint32_t count,
                                 std::size_t min_entry_size,
                                 const char *section) {
  if (pos > end || (min_entry_size != 0 && count > (end - pos) / min_entry_size)) {
    throw std::runtime_error(std::string("HashLink kernel descriptor ") + section + " section is truncated");
  }
}


std::unique_ptr<ExpressionDescriptor> parse_expression(DescriptorReader &reader,
                                                       const KernelDescriptor &descriptor,
                                                       int depth);

std::unique_ptr<StatementDescriptor> parse_statement(DescriptorReader &reader,
                                                     const KernelDescriptor &descriptor,
                                                     int depth);

std::vector<std::unique_ptr<StatementDescriptor>> parse_statement_list(DescriptorReader &reader,
                                                                       const KernelDescriptor &descriptor,
                                                                       std::uint32_t count,
                                                                       int depth) {
  if (depth > 64) {
    throw std::runtime_error("HashLink kernel descriptor nesting is too deep");
  }
  if (count > reader.remaining()) {
    throw std::runtime_error("HashLink kernel descriptor statement section is truncated");
  }
  std::vector<std::unique_ptr<StatementDescriptor>> statements;
  statements.reserve(count);
  for (std::uint32_t i = 0; i < count; ++i) {
    statements.push_back(parse_statement(reader, descriptor, depth + 1));
  }
  return statements;
}

std::vector<std::unique_ptr<ExpressionDescriptor>> parse_indices(DescriptorReader &reader,
                                                                 const KernelDescriptor &descriptor,
                                                                 int depth) {
  const std::uint32_t count = reader.read_u32();
  if (count == 0 || count > 8) {
    throw std::runtime_error("HashLink kernel descriptor index count is out of range");
  }
  std::vector<std::unique_ptr<ExpressionDescriptor>> indices;
  indices.reserve(count);
  for (std::uint32_t i = 0; i < count; ++i) {
    indices.push_back(parse_expression(reader, descriptor, depth + 1));
  }
  return indices;
}

std::unique_ptr<ExpressionDescriptor> parse_expression(DescriptorReader &reader,
                                                       const KernelDescriptor &descriptor,
                                                       int depth) {
  if (depth > 64) {
    throw std::runtime_error("HashLink kernel descriptor expression nesting is too deep");
  }

  auto expr = std::make_unique<ExpressionDescriptor>();
  expr->opcode = parse_expr_opcode(reader.read_u8());
  switch (expr->opcode) {
    case ExprOpcode::const_i32:
      expr->const_i32 = reader.read_i32();
      break;
    case ExprOpcode::const_f64:
      expr->const_f64 = reader.read_f64();
      break;
    case ExprOpcode::const_i64:
      expr->const_i64 = reader.read_i64();
      break;
    case ExprOpcode::const_u64:
      expr->const_u64 = reader.read_u64();
      break;
    case ExprOpcode::const_f32:
      expr->const_f32 = reader.read_f32();
      break;
    case ExprOpcode::const_bool:
      expr->const_bool = reader.read_u8() != 0;
      break;
    case ExprOpcode::thread_idx:
    case ExprOpcode::block_thread_idx:
    case ExprOpcode::subgroup_size:
    case ExprOpcode::subgroup_invocation_id:
    case ExprOpcode::subgroup_elect:
    case ExprOpcode::local_invocation_id:
    case ExprOpcode::global_invocation_id:
    case ExprOpcode::vk_global_thread_idx:
    case ExprOpcode::cuda_active_mask:
      break;
    case ExprOpcode::arg_load:
      expr->index = reader.read_u32();
      if (expr->index >= descriptor.parameters.size()) {
        throw std::runtime_error("HashLink kernel descriptor references an invalid parameter");
      }
      break;
    case ExprOpcode::local_load:
      expr->index = reader.read_u32();
      if (expr->index >= descriptor.locals.size()) {
        throw std::runtime_error("HashLink kernel descriptor references an invalid local");
      }
      break;
    case ExprOpcode::load_index:
      expr->target = parse_expression(reader, descriptor, depth + 1);
      expr->indices = parse_indices(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::shape_axis:
      expr->target = parse_expression(reader, descriptor, depth + 1);
      expr->axis = reader.read_u32();
      break;
    case ExprOpcode::rand:
      expr->cast_dtype = parse_dtype(reader.read_u8());
      break;
    case ExprOpcode::atomic_add:
    case ExprOpcode::atomic_sub:
    case ExprOpcode::atomic_min:
    case ExprOpcode::atomic_max:
    case ExprOpcode::atomic_bit_and:
    case ExprOpcode::atomic_bit_or:
    case ExprOpcode::atomic_bit_xor:
    case ExprOpcode::atomic_exchange:
    case ExprOpcode::atomic_mul:
      expr->target = parse_expression(reader, descriptor, depth + 1);
      expr->indices = parse_indices(reader, descriptor, depth + 1);
      expr->value = parse_expression(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::atomic_compare_exchange:
      expr->target = parse_expression(reader, descriptor, depth + 1);
      expr->indices = parse_indices(reader, descriptor, depth + 1);
      expr->expected = parse_expression(reader, descriptor, depth + 1);
      expr->value = parse_expression(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::binary_add:
    case ExprOpcode::binary_sub:
    case ExprOpcode::binary_mul:
    case ExprOpcode::binary_div:
    case ExprOpcode::binary_mod:
    case ExprOpcode::cmp_eq:
    case ExprOpcode::cmp_ne:
    case ExprOpcode::cmp_lt:
    case ExprOpcode::cmp_le:
    case ExprOpcode::cmp_gt:
    case ExprOpcode::cmp_ge:
    case ExprOpcode::logic_and:
    case ExprOpcode::logic_or:
    case ExprOpcode::bit_and:
    case ExprOpcode::bit_or:
    case ExprOpcode::bit_xor:
    case ExprOpcode::bit_shl:
    case ExprOpcode::bit_shr:
    case ExprOpcode::bit_sar:
    case ExprOpcode::binary_min:
    case ExprOpcode::binary_max:
    case ExprOpcode::binary_atan2:
    case ExprOpcode::binary_pow:
    case ExprOpcode::subgroup_shuffle:
    case ExprOpcode::subgroup_shuffle_down:
    case ExprOpcode::subgroup_shuffle_up:
    case ExprOpcode::subgroup_broadcast:
      expr->lhs = parse_expression(reader, descriptor, depth + 1);
      expr->rhs = parse_expression(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::cast:
    case ExprOpcode::bit_cast:
      expr->cast_dtype = parse_dtype(reader.read_u8());
      expr->operand = parse_expression(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::select:
      expr->operand = parse_expression(reader, descriptor, depth + 1);
      expr->lhs = parse_expression(reader, descriptor, depth + 1);
      expr->rhs = parse_expression(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::logic_not:
    case ExprOpcode::unary_abs:
    case ExprOpcode::unary_sin:
    case ExprOpcode::unary_cos:
    case ExprOpcode::unary_tan:
    case ExprOpcode::unary_exp:
    case ExprOpcode::unary_log:
    case ExprOpcode::unary_sqrt:
    case ExprOpcode::unary_floor:
    case ExprOpcode::unary_ceil:
    case ExprOpcode::unary_asin:
    case ExprOpcode::unary_acos:
    case ExprOpcode::unary_rsqrt:
    case ExprOpcode::unary_round:
    case ExprOpcode::unary_tanh:
    case ExprOpcode::unary_inv:
    case ExprOpcode::unary_rcp:
    case ExprOpcode::unary_popcnt:
    case ExprOpcode::unary_clz:
    case ExprOpcode::unary_ffs:
    case ExprOpcode::unary_sgn:
    case ExprOpcode::unary_neg:
    case ExprOpcode::unary_bit_not:
    case ExprOpcode::block_barrier_and:
    case ExprOpcode::block_barrier_or:
    case ExprOpcode::block_barrier_count:
      expr->operand = parse_expression(reader, descriptor, depth + 1);
      break;
  }
  return expr;
}

std::unique_ptr<StatementDescriptor> parse_statement(DescriptorReader &reader,
                                                     const KernelDescriptor &descriptor,
                                                     int depth) {
  if (depth > 64) {
    throw std::runtime_error("HashLink kernel descriptor statement nesting is too deep");
  }

  auto stmt = std::make_unique<StatementDescriptor>();
  stmt->opcode = parse_stmt_opcode(reader.read_u8());
  switch (stmt->opcode) {
    case StmtOpcode::local_alloc:
      stmt->local_id = reader.read_u32();
      if (stmt->local_id >= descriptor.locals.size()) {
        throw std::runtime_error("HashLink kernel descriptor allocates an invalid local");
      }
      break;
    case StmtOpcode::store_index:
      stmt->target = parse_expression(reader, descriptor, depth + 1);
      stmt->indices = parse_indices(reader, descriptor, depth + 1);
      stmt->value = parse_expression(reader, descriptor, depth + 1);
      break;
    case StmtOpcode::range_for: {
      stmt->local_id = reader.read_u32();
      if (stmt->local_id >= descriptor.locals.size()) {
        throw std::runtime_error("HashLink kernel descriptor range-for uses an invalid local");
      }
      stmt->begin = parse_expression(reader, descriptor, depth + 1);
      stmt->end = parse_expression(reader, descriptor, depth + 1);
      const std::uint32_t body_count = reader.read_u32();
      stmt->body = parse_statement_list(reader, descriptor, body_count, depth + 1);
      break;
    }
    case StmtOpcode::struct_for_external_tensor: {
      stmt->local_id = reader.read_u32();
      if (stmt->local_id >= descriptor.locals.size()) {
        throw std::runtime_error("HashLink kernel descriptor struct-for uses an invalid local");
      }
      stmt->target = parse_expression(reader, descriptor, depth + 1);
      const std::uint32_t body_count = reader.read_u32();
      stmt->body = parse_statement_list(reader, descriptor, body_count, depth + 1);
      break;
    }
    case StmtOpcode::mesh_for: {
      stmt->local_id = reader.read_u32();
      if (stmt->local_id >= descriptor.locals.size()) {
        throw std::runtime_error("HashLink kernel descriptor mesh-for uses an invalid local");
      }
      stmt->mesh_element_type = reader.read_u8();
      if (stmt->mesh_element_type > 3) {
        throw std::runtime_error("HashLink kernel descriptor mesh-for uses an invalid element type");
      }
      for (auto &count : stmt->mesh_num_elements) {
        count = reader.read_u32();
      }
      const std::uint32_t body_count = reader.read_u32();
      stmt->body = parse_statement_list(reader, descriptor, body_count, depth + 1);
      break;
    }
    case StmtOpcode::if_stmt: {
      stmt->condition = parse_expression(reader, descriptor, depth + 1);
      const std::uint32_t body_count = reader.read_u32();
      stmt->body = parse_statement_list(reader, descriptor, body_count, depth + 1);
      const std::uint32_t else_count = reader.read_u32();
      stmt->else_body = parse_statement_list(reader, descriptor, else_count, depth + 1);
      break;
    }
    case StmtOpcode::assign:
      stmt->target = parse_expression(reader, descriptor, depth + 1);
      stmt->value = parse_expression(reader, descriptor, depth + 1);
      break;
    case StmtOpcode::return_void:
      break;
    case StmtOpcode::return_value:
      stmt->value = parse_expression(reader, descriptor, depth + 1);
      break;
    case StmtOpcode::return_values: {
      const std::uint32_t value_count = reader.read_u32();
      if (value_count == 0 || value_count > 32) {
        throw std::runtime_error("HashLink kernel descriptor return value count is out of range");
      }
      stmt->values.reserve(value_count);
      for (std::uint32_t i = 0; i < value_count; ++i) {
        stmt->values.push_back(parse_expression(reader, descriptor, depth + 1));
      }
      break;
    }
    case StmtOpcode::while_stmt: {
      stmt->condition = parse_expression(reader, descriptor, depth + 1);
      const std::uint32_t body_count = reader.read_u32();
      stmt->body = parse_statement_list(reader, descriptor, body_count, depth + 1);
      break;
    }
    case StmtOpcode::break_stmt:
    case StmtOpcode::continue_stmt:
      break;
    case StmtOpcode::atomic_add:
    case StmtOpcode::atomic_sub:
    case StmtOpcode::atomic_min:
    case StmtOpcode::atomic_max:
    case StmtOpcode::atomic_bit_and:
    case StmtOpcode::atomic_bit_or:
    case StmtOpcode::atomic_bit_xor:
    case StmtOpcode::atomic_exchange:
    case StmtOpcode::atomic_mul:
      stmt->target = parse_expression(reader, descriptor, depth + 1);
      stmt->indices = parse_indices(reader, descriptor, depth + 1);
      stmt->value = parse_expression(reader, descriptor, depth + 1);
      break;
    case StmtOpcode::loop_block_dim:
    case StmtOpcode::loop_parallelize:
    case StmtOpcode::loop_serialize:
      stmt->hint_value = reader.read_u32();
      break;
    case StmtOpcode::print_stmt:
      stmt->print_value = reader.read_u8() != 0;
      if (stmt->print_value) {
        stmt->value = parse_expression(reader, descriptor, depth + 1);
      } else {
        stmt->has_message = true;
        stmt->message = reader.read_string(reader.read_u32());
      }
      break;
    case StmtOpcode::assert_stmt:
      stmt->condition = parse_expression(reader, descriptor, depth + 1);
      stmt->has_message = reader.read_u8() != 0;
      if (stmt->has_message) {
        stmt->message = reader.read_string(reader.read_u32());
      }
      break;
    case StmtOpcode::block_barrier:
    case StmtOpcode::block_mem_fence:
    case StmtOpcode::grid_mem_fence:
    case StmtOpcode::workgroup_barrier:
    case StmtOpcode::workgroup_memory_barrier:
    case StmtOpcode::grid_memory_barrier:
    case StmtOpcode::subgroup_barrier:
    case StmtOpcode::subgroup_memory_barrier:
      break;
    case StmtOpcode::warp_barrier:
      stmt->value = parse_expression(reader, descriptor, depth + 1);
      break;
  }
  return stmt;
}


class LoweringContext {
 public:
  LoweringContext(lang::Program &program,
                  lang::Kernel &kernel,
                  const KernelDescriptor &descriptor,
                  std::vector<lang::Expr> params,
                  std::vector<lang::Expr> locals)
      : compile_config_(&program.compile_config()),
        debug_info_(make_debug_info(descriptor)),
        local_descriptors_(&descriptor.locals),
        local_allocated_(descriptor.locals.size(), false),
        params_(std::move(params)),
        locals_(std::move(locals)),
        builder_(kernel.context->builder()) {
  }

  void lower_statements(const std::vector<std::unique_ptr<StatementDescriptor>> &statements) {
    for (const auto &statement : statements) {
      lower_statement(*statement);
    }
  }

 private:
  lang::Expr type_checked(lang::Expr expr) {
    expr.set_dbg_info(debug_info_);
    expr.type_check(compile_config_);
    return expr;
  }

  lang::Expr lower_internal_call(lang::InternalOp opcode, std::vector<lang::Expr> args) {
    return type_checked(lang::Expr::make<lang::InternalFuncCallExpression>(lang::Operations::get(opcode), args));
  }

  void ensure_local_allocated(std::uint32_t local_id) {
    const auto &local = local_descriptors_->at(local_id);
    if (local.shared_size != 0 || !local.allocate || local_allocated_.at(local_id)) {
      return;
    }
    auto id = std::static_pointer_cast<lang::IdExpression>(locals_.at(local_id).expr)->id;
    builder_.insert(std::make_unique<lang::FrontendAllocaStmt>(id, lower_dtype(local.dtype), debug_info_));
    local_allocated_[local_id] = true;
  }

  static lang::mesh::MeshElementType lower_mesh_element_type(std::uint8_t element_type) {
    switch (element_type) {
      case 0:
        return lang::mesh::MeshElementType::Vertex;
      case 1:
        return lang::mesh::MeshElementType::Edge;
      case 2:
        return lang::mesh::MeshElementType::Face;
      case 3:
        return lang::mesh::MeshElementType::Cell;
      default:
        throw std::runtime_error("HashLink kernel descriptor mesh-for uses an invalid element type");
    }
  }

  static lang::mesh::MeshPtr create_mesh(const StatementDescriptor &stmt) {
    lang::mesh::MeshPtr mesh_ptr;
    mesh_ptr.ptr = std::make_shared<lang::mesh::Mesh>();
    mesh_ptr.ptr->num_patches = 1;
    for (std::size_t i = 0; i < stmt.mesh_num_elements.size(); ++i) {
      const auto element_type = lower_mesh_element_type(static_cast<std::uint8_t>(i));
      if (stmt.mesh_num_elements[i] > static_cast<std::uint32_t>(std::numeric_limits<int>::max())) {
        throw std::runtime_error("HashLink kernel descriptor mesh-for element count exceeds int range");
      }
      const int count = static_cast<int>(stmt.mesh_num_elements[i]);
      mesh_ptr.ptr->num_elements[element_type] = count;
      mesh_ptr.ptr->patch_max_element_num[element_type] = count;
    }
    return mesh_ptr;
  }

  lang::Expr lower_expression(const ExpressionDescriptor &expr) {
    switch (expr.opcode) {
      case ExprOpcode::const_i32:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::i32, static_cast<int64>(expr.const_i32)));
      case ExprOpcode::const_f64:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::f64, expr.const_f64));
      case ExprOpcode::const_i64:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::i64, expr.const_i64));
      case ExprOpcode::const_u64:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::u64, expr.const_u64));
      case ExprOpcode::const_f32:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::f32, expr.const_f32));
      case ExprOpcode::const_bool:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::u1, static_cast<int64>(expr.const_bool ? 1 : 0)));
      case ExprOpcode::thread_idx:
        return type_checked(builder_.insert_thread_idx_expr());
      case ExprOpcode::block_thread_idx:
      case ExprOpcode::subgroup_size:
      case ExprOpcode::subgroup_invocation_id:
      case ExprOpcode::subgroup_elect:
      case ExprOpcode::local_invocation_id:
      case ExprOpcode::global_invocation_id:
      case ExprOpcode::vk_global_thread_idx:
      case ExprOpcode::cuda_active_mask:
        return lower_internal_call(lower_internal_expr_opcode(expr.opcode), {});
      case ExprOpcode::shape_axis:
        return type_checked(lang::Expr::make<lang::ExternalTensorShapeAlongAxisExpression>(
            lower_expression(*expr.target), static_cast<int>(expr.axis)));
      case ExprOpcode::arg_load:
        return params_.at(expr.index);
      case ExprOpcode::local_load:
        return locals_.at(expr.index);
      case ExprOpcode::rand:
        return type_checked(lang::expr_rand(lower_dtype(expr.cast_dtype)));
      case ExprOpcode::load_index: {
        lang::ExprGroup indices;
        indices.exprs.reserve(expr.indices.size());
        for (const auto &index : expr.indices) {
          indices.push_back(lower_expression(*index));
        }
        return type_checked(builder_.expr_subscript(lower_expression(*expr.target), indices, debug_info_));
      }
      case ExprOpcode::atomic_add:
      case ExprOpcode::atomic_sub:
      case ExprOpcode::atomic_min:
      case ExprOpcode::atomic_max:
      case ExprOpcode::atomic_bit_and:
      case ExprOpcode::atomic_bit_or:
      case ExprOpcode::atomic_bit_xor:
      case ExprOpcode::atomic_exchange:
      case ExprOpcode::atomic_mul: {
        lang::ExprGroup indices;
        indices.exprs.reserve(expr.indices.size());
        for (const auto &index : expr.indices) {
          indices.push_back(lower_expression(*index));
        }
        lang::Expr dest = builder_.expr_subscript(lower_expression(*expr.target), indices, debug_info_);
        dest.type_check(compile_config_);
        return type_checked(lang::Expr::make<lang::AtomicOpExpression>(lower_atomic_expr_opcode(expr.opcode), dest,
                                                                       lower_expression(*expr.value)));
      }
      case ExprOpcode::atomic_compare_exchange: {
        lang::ExprGroup indices;
        indices.exprs.reserve(expr.indices.size());
        for (const auto &index : expr.indices) {
          indices.push_back(lower_expression(*index));
        }
        lang::Expr dest = builder_.expr_subscript(lower_expression(*expr.target), indices, debug_info_);
        dest.type_check(compile_config_);
        return type_checked(lang::Expr::make<lang::AtomicOpExpression>(lower_atomic_expr_opcode(expr.opcode), dest,
                                                                       lower_expression(*expr.expected),
                                                                       lower_expression(*expr.value)));
      }
      case ExprOpcode::subgroup_shuffle:
      case ExprOpcode::subgroup_shuffle_down:
      case ExprOpcode::subgroup_shuffle_up:
      case ExprOpcode::subgroup_broadcast:
        return lower_internal_call(lower_internal_expr_opcode(expr.opcode),
                                   {lower_expression(*expr.lhs), lower_expression(*expr.rhs)});
      case ExprOpcode::binary_add:
      case ExprOpcode::binary_sub:
      case ExprOpcode::binary_mul:
      case ExprOpcode::binary_div:
      case ExprOpcode::binary_mod:
      case ExprOpcode::cmp_eq:
      case ExprOpcode::cmp_ne:
      case ExprOpcode::cmp_lt:
      case ExprOpcode::cmp_le:
      case ExprOpcode::cmp_gt:
      case ExprOpcode::cmp_ge:
      case ExprOpcode::logic_and:
      case ExprOpcode::logic_or:
      case ExprOpcode::bit_and:
      case ExprOpcode::bit_or:
      case ExprOpcode::bit_xor:
      case ExprOpcode::bit_shl:
      case ExprOpcode::bit_shr:
      case ExprOpcode::bit_sar:
      case ExprOpcode::binary_min:
      case ExprOpcode::binary_max:
      case ExprOpcode::binary_atan2:
      case ExprOpcode::binary_pow:
        return type_checked(lang::Expr::make<lang::BinaryOpExpression>(lower_binary_opcode(expr.opcode), lower_expression(*expr.lhs),
                                                                       lower_expression(*expr.rhs)));
      case ExprOpcode::cast:
        return type_checked(lang::Expr::make<lang::UnaryOpExpression>(lang::UnaryOpType::cast_value,
                                                                      lower_expression(*expr.operand),
                                                                      lower_dtype(expr.cast_dtype)));
      case ExprOpcode::bit_cast:
        return type_checked(lang::Expr::make<lang::UnaryOpExpression>(lang::UnaryOpType::cast_bits,
                                                                      lower_expression(*expr.operand),
                                                                      lower_dtype(expr.cast_dtype)));
      case ExprOpcode::select:
        return type_checked(lang::Expr::make<lang::TernaryOpExpression>(lang::TernaryOpType::select,
                                                                        lower_expression(*expr.operand),
                                                                        lower_expression(*expr.lhs),
                                                                        lower_expression(*expr.rhs)));
      case ExprOpcode::block_barrier_and:
      case ExprOpcode::block_barrier_or:
      case ExprOpcode::block_barrier_count:
        return lower_internal_call(lower_internal_expr_opcode(expr.opcode), {lower_expression(*expr.operand)});
      case ExprOpcode::logic_not:
      case ExprOpcode::unary_abs:
      case ExprOpcode::unary_sin:
      case ExprOpcode::unary_cos:
      case ExprOpcode::unary_tan:
      case ExprOpcode::unary_exp:
      case ExprOpcode::unary_log:
      case ExprOpcode::unary_sqrt:
      case ExprOpcode::unary_floor:
      case ExprOpcode::unary_ceil:
      case ExprOpcode::unary_asin:
      case ExprOpcode::unary_acos:
      case ExprOpcode::unary_rsqrt:
      case ExprOpcode::unary_round:
      case ExprOpcode::unary_tanh:
      case ExprOpcode::unary_inv:
      case ExprOpcode::unary_rcp:
      case ExprOpcode::unary_popcnt:
      case ExprOpcode::unary_clz:
      case ExprOpcode::unary_ffs:
      case ExprOpcode::unary_sgn:
      case ExprOpcode::unary_neg:
      case ExprOpcode::unary_bit_not:
        return type_checked(lang::Expr::make<lang::UnaryOpExpression>(lower_unary_opcode(expr.opcode),
                                                                      lower_expression(*expr.operand)));
    }
    throw std::runtime_error("HashLink kernel descriptor expression could not be lowered");
  }

  void lower_statement(const StatementDescriptor &stmt) {
    switch (stmt.opcode) {
      case StmtOpcode::local_alloc:
        ensure_local_allocated(stmt.local_id);
        return;
      case StmtOpcode::store_index: {
        lang::ExprGroup indices;
        indices.exprs.reserve(stmt.indices.size());
        for (const auto &index : stmt.indices) {
          indices.push_back(lower_expression(*index));
        }
        lang::Expr lhs = builder_.expr_subscript(lower_expression(*stmt.target), indices, debug_info_);
        lhs.type_check(compile_config_);
        builder_.expr_assign(lhs, lower_expression(*stmt.value), debug_info_);
        return;
      }
      case StmtOpcode::range_for:
        builder_.begin_frontend_range_for(locals_.at(stmt.local_id), lower_expression(*stmt.begin), lower_expression(*stmt.end), debug_info_);
        lower_statements(stmt.body);
        builder_.pop_scope();
        return;
      case StmtOpcode::struct_for_external_tensor: {
        lang::ExprGroup loop_vars;
        loop_vars.push_back(locals_.at(stmt.local_id));
        builder_.begin_frontend_struct_for_on_external_tensor(loop_vars, lower_expression(*stmt.target), debug_info_);
        lower_statements(stmt.body);
        builder_.pop_scope();
        return;
      }
      case StmtOpcode::mesh_for: {
        const auto mesh_ptr = create_mesh(stmt);
        builder_.begin_frontend_mesh_for(locals_.at(stmt.local_id),
                                         mesh_ptr,
                                         lower_mesh_element_type(stmt.mesh_element_type),
                                         debug_info_);
        lower_statements(stmt.body);
        builder_.pop_scope();
        return;
      }
      case StmtOpcode::if_stmt:
        builder_.begin_frontend_if(lower_expression(*stmt.condition), debug_info_);
        builder_.begin_frontend_if_true();
        lower_statements(stmt.body);
        builder_.pop_scope();
        builder_.begin_frontend_if_false();
        lower_statements(stmt.else_body);
        builder_.pop_scope();
        return;
      case StmtOpcode::assign: {
        if (stmt.target->opcode == ExprOpcode::local_load) {
          ensure_local_allocated(stmt.target->index);
        }
        lang::Expr target = lower_expression(*stmt.target);
        target.type_check(compile_config_);
        builder_.expr_assign(target, lower_expression(*stmt.value), debug_info_);
        return;
      }
      case StmtOpcode::return_void:
        return;
      case StmtOpcode::return_value: {
        lang::ExprGroup values;
        values.push_back(lower_expression(*stmt.value));
        builder_.create_kernel_exprgroup_return(values, debug_info_);
        return;
      }
      case StmtOpcode::return_values: {
        lang::ExprGroup values;
        values.exprs.reserve(stmt.values.size());
        for (const auto &value : stmt.values) {
          values.push_back(lower_expression(*value));
        }
        builder_.create_kernel_exprgroup_return(values, debug_info_);
        return;
      }
      case StmtOpcode::while_stmt:
        builder_.begin_frontend_while(lower_expression(*stmt.condition), debug_info_);
        lower_statements(stmt.body);
        builder_.pop_scope();
        return;
      case StmtOpcode::break_stmt:
        builder_.insert_break_stmt(debug_info_);
        return;
      case StmtOpcode::continue_stmt:
        builder_.insert_continue_stmt(debug_info_);
        return;
      case StmtOpcode::loop_block_dim:
        builder_.block_dim(static_cast<int>(stmt.hint_value));
        return;
      case StmtOpcode::loop_parallelize:
        builder_.parallelize(static_cast<int>(stmt.hint_value));
        return;
      case StmtOpcode::loop_serialize:
        builder_.strictly_serialize();
        return;
      case StmtOpcode::print_stmt: {
        std::vector<std::variant<lang::Expr, std::string>> contents;
        std::vector<std::optional<std::string>> formats;
        if (stmt.print_value) {
          contents.emplace_back(lower_expression(*stmt.value));
        } else {
          contents.emplace_back(stmt.message);
        }
        formats.emplace_back(std::nullopt);
        builder_.create_print(std::move(contents), std::move(formats), debug_info_);
        return;
      }
      case StmtOpcode::assert_stmt:
        builder_.create_assert_stmt(lower_expression(*stmt.condition),
                                    stmt.has_message ? stmt.message : std::string("Quadrants assertion failed"),
                                    {},
                                    debug_info_);
        return;
      case StmtOpcode::block_barrier:
      case StmtOpcode::block_mem_fence:
      case StmtOpcode::grid_mem_fence:
      case StmtOpcode::workgroup_barrier:
      case StmtOpcode::workgroup_memory_barrier:
      case StmtOpcode::grid_memory_barrier:
      case StmtOpcode::subgroup_barrier:
      case StmtOpcode::subgroup_memory_barrier:
        builder_.insert_expr_stmt(lower_internal_call(lower_internal_stmt_opcode(stmt.opcode), {}));
        return;
      case StmtOpcode::warp_barrier:
        builder_.insert_expr_stmt(lower_internal_call(lower_internal_stmt_opcode(stmt.opcode), {lower_expression(*stmt.value)}));
        return;
      case StmtOpcode::atomic_add:
      case StmtOpcode::atomic_sub:
      case StmtOpcode::atomic_min:
      case StmtOpcode::atomic_max:
      case StmtOpcode::atomic_bit_and:
      case StmtOpcode::atomic_bit_or:
      case StmtOpcode::atomic_bit_xor:
      case StmtOpcode::atomic_exchange:
      case StmtOpcode::atomic_mul: {
        lang::ExprGroup indices;
        indices.exprs.reserve(stmt.indices.size());
        for (const auto &index : stmt.indices) {
          indices.push_back(lower_expression(*index));
        }
        lang::Expr dest = builder_.expr_subscript(lower_expression(*stmt.target), indices, debug_info_);
        dest.type_check(compile_config_);
        auto op = lower_atomic_stmt_opcode(stmt.opcode);
        builder_.insert_expr_stmt(type_checked(lang::Expr::make<lang::AtomicOpExpression>(op, dest, lower_expression(*stmt.value))));
        return;
      }
    }
    throw std::runtime_error("HashLink kernel descriptor statement could not be lowered");
  }

  const lang::CompileConfig *compile_config_{nullptr};
  lang::DebugInfo debug_info_;
  const std::vector<LocalDescriptor> *local_descriptors_{nullptr};
  std::vector<bool> local_allocated_;
  std::vector<lang::Expr> params_;
  std::vector<lang::Expr> locals_;
  lang::ASTBuilder &builder_;
};

}  // namespace

KernelDescriptor decode_descriptor(const std::uint8_t *data) {
  if (data == nullptr) {
    throw std::runtime_error("HashLink kernel descriptor is null");
  }
  DescriptorReader header_reader(data, kHeaderSize);
  const std::uint32_t magic = header_reader.read_u32();
  if (magic != kMagic) {
    throw std::runtime_error("HashLink kernel descriptor has invalid magic");
  }
  const std::uint32_t version = header_reader.read_u32();
  if (version != kVersion) {
    throw std::runtime_error("HashLink kernel descriptor has unsupported version");
  }
  header_reader.read_u32();
  header_reader.read_u32();
  const std::uint32_t total_size = header_reader.read_u32();
  if (total_size < kHeaderSize || total_size == kUnknownSize) {
    throw std::runtime_error("HashLink kernel descriptor has invalid size");
  }
  return decode_descriptor(data, total_size);
}

KernelDescriptor decode_descriptor(const std::uint8_t *data, std::size_t size) {
  if (size < kHeaderSize) {
    throw std::runtime_error("HashLink kernel descriptor is shorter than its header");
  }

  DescriptorReader reader(data, size);
  const std::uint32_t magic = reader.read_u32();
  if (magic != kMagic) {
    throw std::runtime_error("HashLink kernel descriptor has invalid magic");
  }
  const std::uint32_t version = reader.read_u32();
  if (version != kVersion) {
    throw std::runtime_error("HashLink kernel descriptor has unsupported version");
  }

  {
    const std::uint32_t section_count = reader.read_u32();
    const std::uint32_t section_table_offset = reader.read_u32();
    const std::uint32_t total_size = reader.read_u32();
    if (total_size != size || total_size < kHeaderSize) {
      throw std::runtime_error("HashLink v2 kernel descriptor has invalid size");
    }
    if (section_table_offset < kHeaderSize || section_table_offset > total_size) {
      throw std::runtime_error("HashLink v2 kernel descriptor section table offset is invalid");
    }
    if (section_count > (total_size - section_table_offset) / 12) {
      throw std::runtime_error("HashLink v2 kernel descriptor section table is truncated");
    }

    struct Section {
      std::uint32_t offset{0};
      std::uint32_t size{0};
      bool present{false};
    };
    std::array<Section, 11> sections{};
    reader.seek(section_table_offset);
    for (std::uint32_t i = 0; i < section_count; ++i) {
      const std::uint32_t kind = reader.read_u32();
      const std::uint32_t section_offset = reader.read_u32();
      const std::uint32_t section_size = reader.read_u32();
      if (kind == 0 || kind >= sections.size()) {
        throw std::runtime_error("HashLink v2 kernel descriptor has an unknown section kind");
      }
      if (sections[kind].present) {
        throw std::runtime_error("HashLink v2 kernel descriptor has a duplicate section");
      }
      if (section_offset > total_size || section_size > total_size - section_offset) {
        throw std::runtime_error("HashLink v2 kernel descriptor section range is invalid");
      }
      sections[kind] = Section{section_offset, section_size, true};
    }

    auto require_section = [&](std::uint32_t kind, const char *name) -> Section {
      if (kind >= sections.size() || !sections[kind].present) {
        throw std::runtime_error(std::string("HashLink v2 kernel descriptor is missing ") + name + " section");
      }
      return sections[kind];
    };

    KernelDescriptor descriptor;

    const Section strings = require_section(1, "Strings");
    reader.seek(strings.offset);
    const std::size_t strings_end = strings.offset + strings.size;
    const std::uint32_t string_count = reader.read_u32();
    require_section_entries_fit(reader.pos(), strings_end, string_count, sizeof(std::uint32_t), "string");
    descriptor.strings.reserve(string_count);
    for (std::uint32_t i = 0; i < string_count; ++i) {
      const std::uint32_t len = reader.read_u32();
      if (reader.pos() > strings_end || len > strings_end - reader.pos()) {
        throw std::runtime_error("HashLink v2 kernel descriptor string section is truncated");
      }
      descriptor.strings.push_back(reader.read_string(len));
    }
    if (reader.pos() != strings_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor string section has trailing data");
    }

    const Section source_spans = require_section(2, "SourceSpans");
    reader.seek(source_spans.offset);
    const std::size_t source_spans_end = source_spans.offset + source_spans.size;
    const std::uint32_t source_span_count = reader.read_u32();
    const std::size_t remaining_source_span_bytes = source_spans_end - reader.pos();
    const bool source_spans_have_line =
        source_span_count != 0 && remaining_source_span_bytes == static_cast<std::size_t>(source_span_count) * 16;
    const std::size_t source_span_entry_size = source_spans_have_line ? 16 : 12;
    require_section_entries_fit(reader.pos(), source_spans_end, source_span_count, source_span_entry_size, "source span");
    descriptor.source_spans.reserve(source_span_count);
    for (std::uint32_t i = 0; i < source_span_count; ++i) {
      SourceSpanDescriptor span;
      span.file_name_id = reader.read_u32();
      if (source_spans_have_line) {
        span.line = reader.read_u32();
      }
      span.begin = reader.read_u32();
      span.end = reader.read_u32();
      checked_string(descriptor, span.file_name_id, "source span file");
      descriptor.source_spans.push_back(span);
    }
    if (reader.pos() != source_spans_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor source span section has trailing data");
    }

    const Section symbols = require_section(5, "Symbols");
    reader.seek(symbols.offset);
    const std::size_t symbols_end = symbols.offset + symbols.size;
    const std::uint32_t params_size = reader.read_u32();
    if (params_size > symbols_end - reader.pos()) {
      throw std::runtime_error("HashLink v2 kernel descriptor symbol parameter table is truncated");
    }
    const std::size_t params_end = reader.pos() + params_size;
    const std::uint32_t parameter_count = reader.read_u32();
    require_section_entries_fit(reader.pos(), params_end, parameter_count, 8, "parameter");
    descriptor.parameters.reserve(parameter_count);
    for (std::uint32_t i = 0; i < parameter_count; ++i) {
      ParameterDescriptor param;
      param.kind = parse_parameter_kind(reader.read_u8());
      param.dtype = parse_dtype(reader.read_u8());
      param.rank = reader.read_u8();
      reader.read_u8();
      param.name_id = reader.read_u32();
      checked_string(descriptor, param.name_id, "parameter name");
      if (param.kind == ParameterKind::scalar && param.rank != 0) {
        throw std::runtime_error("HashLink scalar parameter rank must be zero");
      }
      if (param.kind == ParameterKind::ndarray && param.rank == 0) {
        throw std::runtime_error("HashLink ndarray parameter rank must be positive");
      }
      descriptor.parameters.push_back(param);
    }
    if (reader.pos() != params_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor parameter table has trailing data");
    }
    if (reader.pos() + sizeof(std::uint32_t) > symbols_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor symbol local table is truncated");
    }
    const std::uint32_t locals_size = reader.read_u32();
    if (locals_size > symbols_end - reader.pos()) {
      throw std::runtime_error("HashLink v2 kernel descriptor symbol local table is truncated");
    }
    const std::size_t locals_end = reader.pos() + locals_size;
    const std::uint32_t local_count = reader.read_u32();
    const std::size_t local_entry_bytes =
        local_count != 0 && locals_end - reader.pos() == static_cast<std::size_t>(local_count) * 12 ? 12 : 8;
    require_section_entries_fit(reader.pos(), locals_end, local_count, local_entry_bytes, "local");
    descriptor.locals.reserve(local_count);
    for (std::uint32_t i = 0; i < local_count; ++i) {
      LocalDescriptor local;
      local.dtype = parse_dtype(reader.read_u8());
      local.allocate = reader.read_u8() != 0;
      reader.read_u8();
      reader.read_u8();
      local.name_id = reader.read_u32();
      if (local_entry_bytes == 12) {
        local.shared_size = reader.read_u32();
      }
      checked_string(descriptor, local.name_id, "local name");
      descriptor.locals.push_back(local);
    }
    if (reader.pos() != symbols_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor symbol section has trailing data");
    }

    const Section functions = require_section(8, "Functions");
    reader.seek(functions.offset);
    const std::size_t functions_end = functions.offset + functions.size;
    const std::uint32_t function_count = reader.read_u32();
    descriptor.functions.reserve(function_count);
    const bool legacy_function_section =
        function_count != 0 && functions_end - reader.pos() == static_cast<std::size_t>(function_count) * sizeof(std::uint32_t);
    for (std::uint32_t i = 0; i < function_count; ++i) {
      FunctionDescriptor function;
      function.name_id = reader.read_u32();
      checked_string(descriptor, function.name_id, "function name");
      if (!legacy_function_section) {
        function.has_return = reader.read_u8() != 0;
        function.return_dtype = parse_dtype(reader.read_u8());
        reader.read_u8();
        reader.read_u8();
        const std::uint32_t arg_count = reader.read_u32();
        require_section_entries_fit(reader.pos(), functions_end, arg_count, 8, "function parameter");
        function.parameters.reserve(arg_count);
        for (std::uint32_t arg_id = 0; arg_id < arg_count; ++arg_id) {
          ParameterDescriptor param;
          param.kind = parse_parameter_kind(reader.read_u8());
          param.dtype = parse_dtype(reader.read_u8());
          param.rank = reader.read_u8();
          reader.read_u8();
          param.name_id = reader.read_u32();
          checked_string(descriptor, param.name_id, "function parameter name");
          if (param.kind == ParameterKind::scalar && param.rank != 0) {
            throw std::runtime_error("HashLink scalar function parameter rank must be zero");
          }
          if (param.kind == ParameterKind::ndarray && param.rank == 0) {
            throw std::runtime_error("HashLink ndarray function parameter rank must be positive");
          }
          function.parameters.push_back(param);
        }
      }
      descriptor.functions.push_back(std::move(function));
    }
    if (reader.pos() != functions_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor function section has trailing data");
    }

    const Section statements = require_section(7, "Statements");
    reader.seek(statements.offset);
    const std::size_t statements_end = statements.offset + statements.size;
    descriptor.kernel_name_id = reader.read_u32();
    checked_string(descriptor, descriptor.kernel_name_id, "kernel name");
    const std::uint32_t statement_count = reader.read_u32();
    descriptor.statements = parse_statement_list(reader, descriptor, statement_count, 0);
    if (reader.pos() + 2 <= statements_end) {
      descriptor.has_return = reader.read_u8() != 0;
      descriptor.return_dtype = parse_dtype(reader.read_u8());
      if (descriptor.has_return) {
        descriptor.return_dtypes.push_back(descriptor.return_dtype);
      }
    }
    if (reader.pos() + sizeof(std::uint32_t) <= statements_end) {
      const std::uint32_t return_count = reader.read_u32();
      if (return_count > 32) {
        throw std::runtime_error("HashLink kernel descriptor return count is out of range");
      }
      if (return_count > statements_end - reader.pos()) {
        throw std::runtime_error("HashLink v2 kernel descriptor return dtype table is truncated");
      }
      if (return_count == 0) {
        if (descriptor.has_return) {
          throw std::runtime_error("HashLink kernel descriptor return metadata is inconsistent");
        }
      } else {
        descriptor.return_dtypes.clear();
        descriptor.return_dtypes.reserve(return_count);
        for (std::uint32_t i = 0; i < return_count; ++i) {
          descriptor.return_dtypes.push_back(parse_dtype(reader.read_u8()));
        }
        descriptor.has_return = true;
        descriptor.return_dtype = descriptor.return_dtypes.front();
      }
    }
    if (reader.pos() != statements_end) {
      throw std::runtime_error("HashLink v2 kernel descriptor statement section has trailing data");
    }
    validate_descriptor(descriptor);
    return descriptor;
  }
}

AutodiffMode autodiff_mode_from_bridge_id(int mode) {
  switch (mode) {
    case 0:
      return AutodiffMode::kNone;
    case 1:
      return AutodiffMode::kForward;
    case 2:
      return AutodiffMode::kReverse;
    case 3:
      return AutodiffMode::kCheckAutodiffValid;
    default:
      throw std::runtime_error("Unsupported HashLink autodiff mode id: " + std::to_string(mode));
  }
}


KernelBuildResult build_kernel_from_descriptor(lang::Program &program,
                                              const KernelDescriptor &descriptor,
                                              AutodiffMode autodiff_mode) {
  const std::string kernel_name = checked_string(descriptor, descriptor.kernel_name_id, "kernel name");
  const lang::DebugInfo debug_info = make_debug_info(descriptor);

  lang::Kernel *kernel_ptr = nullptr;
  lang::Kernel &kernel = program.create_kernel(
      [&](lang::Kernel *kernel) {
        std::vector<std::vector<int>> arg_ids;
        arg_ids.reserve(descriptor.parameters.size());
        for (const auto &param : descriptor.parameters) {
          const std::string name = checked_string(descriptor, param.name_id, "parameter name");
          if (param.kind == ParameterKind::scalar) {
            arg_ids.push_back(kernel->insert_scalar_param(lower_dtype(param.dtype), name));
          } else {
            arg_ids.push_back(kernel->insert_ndarray_param(lower_dtype(param.dtype), param.rank, name, false));
          }
        }
        kernel->finalize_params();
        for (const auto dtype : descriptor.return_dtypes) {
          kernel->insert_ret(lower_dtype(dtype));
        }
        kernel->finalize_rets();

        std::vector<lang::Expr> params;
        params.reserve(descriptor.parameters.size());
        for (std::size_t i = 0; i < descriptor.parameters.size(); ++i) {
          const auto &param = descriptor.parameters[i];
          lang::Expr expr;
          if (param.kind == ParameterKind::scalar) {
            expr = lang::Expr::make<lang::ArgLoadExpression>(arg_ids[i], lower_dtype(param.dtype), false, true,
                                                             debug_info);
          } else {
            expr = lang::Expr::make<lang::ExternalTensorExpression>(lower_dtype(param.dtype), param.rank, arg_ids[i],
                                                                    false, BoundaryMode::kUnsafe);
          }
          expr.set_dbg_info(debug_info);
          expr.type_check(&program.compile_config());
          params.push_back(expr);
        }

        std::vector<lang::Expr> locals;
        locals.reserve(descriptor.locals.size());
        for (const auto &local : descriptor.locals) {
          lang::Expr expr;
          if (local.shared_size != 0) {
            expr = kernel->context->builder().expr_alloca_shared_array({static_cast<int>(local.shared_size)},
                                                                       lower_dtype(local.dtype),
                                                                       debug_info);
          } else {
            expr = kernel->context->builder().make_id_expr(checked_string(descriptor, local.name_id, "local name"));
            expr.expr->ret_type = lower_dtype(local.dtype);
          }
          expr.set_dbg_info(debug_info);
          locals.push_back(expr);
        }

        LoweringContext lowering(program, *kernel, descriptor, std::move(params), std::move(locals));
        lowering.lower_statements(descriptor.statements);
      },
      kernel_name, autodiff_mode);
  kernel_ptr = &kernel;

  lang::CompileResult compile_result = program.compile_kernel(program.compile_config(), program.get_device_caps(), kernel);
  return KernelBuildResult{kernel_ptr, &compile_result.compiled_kernel_data};
}

}  // namespace quadrants::hashlink
