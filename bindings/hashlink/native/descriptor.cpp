#include "bindings/hashlink/native/descriptor.h"

#include <algorithm>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <utility>

#include "quadrants/compilation_manager/kernel_compilation_manager.h"
#include "quadrants/ir/frontend_ir.h"
#include "quadrants/ir/type.h"
#include "quadrants/program/kernel.h"
#include "quadrants/program/program.h"

namespace quadrants::hashlink {
namespace {

constexpr std::size_t kHeaderSize = 28;
constexpr std::uint32_t kMagic = 0x4c484451;  // "QDHL", little-endian.
constexpr std::uint32_t kVersion = 1;
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

void require_section_entries_fit(std::size_t pos,
                                 std::size_t end,
                                 std::uint32_t count,
                                 std::size_t min_entry_size,
                                 const char *section) {
  if (pos > end || (min_entry_size != 0 && count > (end - pos) / min_entry_size)) {
    throw std::runtime_error(std::string("HashLink kernel descriptor ") + section + " section is truncated");
  }
}

DescriptorDType parse_dtype(std::uint8_t value) {
  switch (static_cast<DescriptorDType>(value)) {
    case DescriptorDType::i8:
    case DescriptorDType::i16:
    case DescriptorDType::i32:
    case DescriptorDType::i64:
    case DescriptorDType::u8:
    case DescriptorDType::u16:
    case DescriptorDType::u32:
    case DescriptorDType::u64:
    case DescriptorDType::f32:
    case DescriptorDType::f64:
      return static_cast<DescriptorDType>(value);
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported dtype");
}

lang::DataType lower_dtype(DescriptorDType dtype) {
  switch (dtype) {
    case DescriptorDType::i8:
      return lang::PrimitiveType::i8;
    case DescriptorDType::i16:
      return lang::PrimitiveType::i16;
    case DescriptorDType::i32:
      return lang::PrimitiveType::i32;
    case DescriptorDType::i64:
      return lang::PrimitiveType::i64;
    case DescriptorDType::u8:
      return lang::PrimitiveType::u8;
    case DescriptorDType::u16:
      return lang::PrimitiveType::u16;
    case DescriptorDType::u32:
      return lang::PrimitiveType::u32;
    case DescriptorDType::u64:
      return lang::PrimitiveType::u64;
    case DescriptorDType::f32:
      return lang::PrimitiveType::f32;
    case DescriptorDType::f64:
      return lang::PrimitiveType::f64;
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported dtype");
}

ParameterKind parse_parameter_kind(std::uint8_t value) {
  switch (static_cast<ParameterKind>(value)) {
    case ParameterKind::scalar:
      return ParameterKind::scalar;
    case ParameterKind::ndarray:
      return ParameterKind::ndarray;
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported parameter kind");
}

ExprOpcode parse_expr_opcode(std::uint8_t value) {
  switch (static_cast<ExprOpcode>(value)) {
    case ExprOpcode::const_i32:
    case ExprOpcode::const_f64:
    case ExprOpcode::atomic_add:
    case ExprOpcode::arg_load:
    case ExprOpcode::local_load:
    case ExprOpcode::load_index:
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
    case ExprOpcode::logic_not:
    case ExprOpcode::bit_and:
    case ExprOpcode::bit_or:
    case ExprOpcode::bit_xor:
    case ExprOpcode::bit_shl:
    case ExprOpcode::bit_shr:
    case ExprOpcode::bit_sar:
    case ExprOpcode::unary_abs:
    case ExprOpcode::unary_sin:
    case ExprOpcode::unary_cos:
    case ExprOpcode::unary_tan:
    case ExprOpcode::unary_exp:
    case ExprOpcode::unary_log:
    case ExprOpcode::unary_sqrt:
    case ExprOpcode::unary_floor:
    case ExprOpcode::unary_ceil:
    case ExprOpcode::binary_min:
    case ExprOpcode::binary_max:
    case ExprOpcode::unary_neg:
    case ExprOpcode::unary_bit_not:
    case ExprOpcode::cast:
    case ExprOpcode::select:
      return static_cast<ExprOpcode>(value);
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported expression opcode");
}

StmtOpcode parse_stmt_opcode(std::uint8_t value) {
  switch (static_cast<StmtOpcode>(value)) {
    case StmtOpcode::local_alloc:
    case StmtOpcode::store_index:
    case StmtOpcode::range_for:
    case StmtOpcode::if_stmt:
    case StmtOpcode::assign:
    case StmtOpcode::return_void:
    case StmtOpcode::while_stmt:
    case StmtOpcode::break_stmt:
    case StmtOpcode::continue_stmt:
    case StmtOpcode::atomic_add:
    case StmtOpcode::atomic_sub:
      return static_cast<StmtOpcode>(value);
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported statement opcode");
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
    case ExprOpcode::atomic_add:
      expr->target = parse_expression(reader, descriptor, depth + 1);
      expr->indices = parse_indices(reader, descriptor, depth + 1);
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
      expr->lhs = parse_expression(reader, descriptor, depth + 1);
      expr->rhs = parse_expression(reader, descriptor, depth + 1);
      break;
    case ExprOpcode::cast:
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
    case ExprOpcode::unary_neg:
    case ExprOpcode::unary_bit_not:
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
      stmt->target = parse_expression(reader, descriptor, depth + 1);
      stmt->indices = parse_indices(reader, descriptor, depth + 1);
      stmt->value = parse_expression(reader, descriptor, depth + 1);
      break;
  }
  return stmt;
}

lang::UnaryOpType lower_unary_opcode(ExprOpcode opcode) {
  switch (opcode) {
    case ExprOpcode::logic_not:
      return lang::UnaryOpType::logic_not;
    case ExprOpcode::unary_abs:
      return lang::UnaryOpType::abs;
    case ExprOpcode::unary_sin:
      return lang::UnaryOpType::sin;
    case ExprOpcode::unary_cos:
      return lang::UnaryOpType::cos;
    case ExprOpcode::unary_tan:
      return lang::UnaryOpType::tan;
    case ExprOpcode::unary_exp:
      return lang::UnaryOpType::exp;
    case ExprOpcode::unary_log:
      return lang::UnaryOpType::log;
    case ExprOpcode::unary_sqrt:
      return lang::UnaryOpType::sqrt;
    case ExprOpcode::unary_floor:
      return lang::UnaryOpType::floor;
    case ExprOpcode::unary_ceil:
      return lang::UnaryOpType::ceil;
    case ExprOpcode::unary_neg:
      return lang::UnaryOpType::neg;
    case ExprOpcode::unary_bit_not:
      return lang::UnaryOpType::bit_not;
    default:
      break;
  }
  throw std::runtime_error("HashLink kernel descriptor expression is not a unary operation");
}

lang::BinaryOpType lower_binary_opcode(ExprOpcode opcode) {
  switch (opcode) {
    case ExprOpcode::binary_add:
      return lang::BinaryOpType::add;
    case ExprOpcode::binary_sub:
      return lang::BinaryOpType::sub;
    case ExprOpcode::binary_mul:
      return lang::BinaryOpType::mul;
    case ExprOpcode::binary_div:
      return lang::BinaryOpType::div;
    case ExprOpcode::binary_mod:
      return lang::BinaryOpType::mod;
    case ExprOpcode::cmp_eq:
      return lang::BinaryOpType::cmp_eq;
    case ExprOpcode::cmp_ne:
      return lang::BinaryOpType::cmp_ne;
    case ExprOpcode::cmp_lt:
      return lang::BinaryOpType::cmp_lt;
    case ExprOpcode::cmp_le:
      return lang::BinaryOpType::cmp_le;
    case ExprOpcode::cmp_gt:
      return lang::BinaryOpType::cmp_gt;
    case ExprOpcode::cmp_ge:
      return lang::BinaryOpType::cmp_ge;
    case ExprOpcode::logic_and:
      return lang::BinaryOpType::logical_and;
    case ExprOpcode::logic_or:
      return lang::BinaryOpType::logical_or;
    case ExprOpcode::bit_and:
      return lang::BinaryOpType::bit_and;
    case ExprOpcode::bit_or:
      return lang::BinaryOpType::bit_or;
    case ExprOpcode::bit_xor:
      return lang::BinaryOpType::bit_xor;
    case ExprOpcode::bit_shl:
      return lang::BinaryOpType::bit_shl;
    case ExprOpcode::bit_shr:
      return lang::BinaryOpType::bit_shr;
    case ExprOpcode::bit_sar:
      return lang::BinaryOpType::bit_sar;
    case ExprOpcode::binary_min:
      return lang::BinaryOpType::min;
    case ExprOpcode::binary_max:
      return lang::BinaryOpType::max;
    default:
      break;
  }
  throw std::runtime_error("HashLink kernel descriptor expression is not a binary operation");
}

class LoweringContext {
 public:
  LoweringContext(lang::Program &program,
                  lang::Kernel &kernel,
                  const KernelDescriptor &descriptor,
                  std::vector<lang::Expr> params,
                  std::vector<lang::Expr> locals)
      : compile_config_(&program.compile_config()),
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
    expr.type_check(compile_config_);
    return expr;
  }

  void ensure_local_allocated(std::uint32_t local_id) {
    const auto &local = local_descriptors_->at(local_id);
    if (!local.allocate || local_allocated_.at(local_id)) {
      return;
    }
    auto id = std::static_pointer_cast<lang::IdExpression>(locals_.at(local_id).expr)->id;
    builder_.insert(std::make_unique<lang::FrontendAllocaStmt>(id, lower_dtype(local.dtype)));
    local_allocated_[local_id] = true;
  }

  lang::Expr lower_expression(const ExpressionDescriptor &expr) {
    switch (expr.opcode) {
      case ExprOpcode::const_i32:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::i32, static_cast<int64>(expr.const_i32)));
      case ExprOpcode::const_f64:
        return type_checked(lang::Expr::make<lang::ConstExpression>(lang::PrimitiveType::f64, expr.const_f64));
      case ExprOpcode::arg_load:
        return params_.at(expr.index);
      case ExprOpcode::local_load:
        return locals_.at(expr.index);
      case ExprOpcode::load_index: {
        lang::ExprGroup indices;
        indices.exprs.reserve(expr.indices.size());
        for (const auto &index : expr.indices) {
          indices.push_back(lower_expression(*index));
        }
        return type_checked(builder_.expr_subscript(lower_expression(*expr.target), indices));
      }
      case ExprOpcode::atomic_add: {
        lang::ExprGroup indices;
        indices.exprs.reserve(expr.indices.size());
        for (const auto &index : expr.indices) {
          indices.push_back(lower_expression(*index));
        }
        lang::Expr dest = builder_.expr_subscript(lower_expression(*expr.target), indices);
        dest.type_check(compile_config_);
        return type_checked(lang::Expr::make<lang::AtomicOpExpression>(lang::AtomicOpType::add, dest,
                                                                       lower_expression(*expr.value)));
      }
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
        return type_checked(lang::Expr::make<lang::BinaryOpExpression>(lower_binary_opcode(expr.opcode), lower_expression(*expr.lhs),
                                                                       lower_expression(*expr.rhs)));
      case ExprOpcode::cast:
        return type_checked(lang::Expr::make<lang::UnaryOpExpression>(lang::UnaryOpType::cast_value,
                                                                      lower_expression(*expr.operand),
                                                                      lower_dtype(expr.cast_dtype)));
      case ExprOpcode::select:
        return type_checked(lang::Expr::make<lang::TernaryOpExpression>(lang::TernaryOpType::select,
                                                                        lower_expression(*expr.operand),
                                                                        lower_expression(*expr.lhs),
                                                                        lower_expression(*expr.rhs)));
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
        lang::Expr lhs = builder_.expr_subscript(lower_expression(*stmt.target), indices);
        lhs.type_check(compile_config_);
        builder_.expr_assign(lhs, lower_expression(*stmt.value));
        return;
      }
      case StmtOpcode::range_for:
        builder_.begin_frontend_range_for(locals_.at(stmt.local_id), lower_expression(*stmt.begin), lower_expression(*stmt.end));
        lower_statements(stmt.body);
        builder_.pop_scope();
        return;
      case StmtOpcode::if_stmt:
        builder_.begin_frontend_if(lower_expression(*stmt.condition));
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
        builder_.expr_assign(target, lower_expression(*stmt.value));
        return;
      }
      case StmtOpcode::return_void:
        return;
      case StmtOpcode::while_stmt:
        builder_.begin_frontend_while(lower_expression(*stmt.condition));
        lower_statements(stmt.body);
        builder_.pop_scope();
        return;
      case StmtOpcode::break_stmt:
        builder_.insert_break_stmt();
        return;
      case StmtOpcode::continue_stmt:
        builder_.insert_continue_stmt();
        return;
      case StmtOpcode::atomic_add:
      case StmtOpcode::atomic_sub: {
        lang::ExprGroup indices;
        indices.exprs.reserve(stmt.indices.size());
        for (const auto &index : stmt.indices) {
          indices.push_back(lower_expression(*index));
        }
        lang::Expr dest = builder_.expr_subscript(lower_expression(*stmt.target), indices);
        dest.type_check(compile_config_);
        auto op = stmt.opcode == StmtOpcode::atomic_add ? lang::AtomicOpType::add : lang::AtomicOpType::sub;
        builder_.insert_expr_stmt(type_checked(lang::Expr::make<lang::AtomicOpExpression>(op, dest, lower_expression(*stmt.value))));
        return;
      }
    }
    throw std::runtime_error("HashLink kernel descriptor statement could not be lowered");
  }

  const lang::CompileConfig *compile_config_{nullptr};
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

  const std::uint32_t strings_offset = reader.read_u32();
  const std::uint32_t params_offset = reader.read_u32();
  const std::uint32_t locals_offset = reader.read_u32();
  const std::uint32_t statements_offset = reader.read_u32();
  const std::uint32_t total_size = reader.read_u32();

  if (total_size != size) {
    throw std::runtime_error("HashLink kernel descriptor size does not match its header");
  }
  if (!(kHeaderSize <= strings_offset && strings_offset <= params_offset && params_offset <= locals_offset &&
        locals_offset <= statements_offset && statements_offset < total_size)) {
    throw std::runtime_error("HashLink kernel descriptor section offsets are invalid");
  }

  KernelDescriptor descriptor;

  reader.seek(strings_offset);
  const std::uint32_t string_count = reader.read_u32();
  require_section_entries_fit(reader.pos(), params_offset, string_count, sizeof(std::uint32_t), "string");
  descriptor.strings.reserve(string_count);
  for (std::uint32_t i = 0; i < string_count; ++i) {
    const std::uint32_t len = reader.read_u32();
    if (reader.pos() > params_offset || len > params_offset - reader.pos()) {
      throw std::runtime_error("HashLink kernel descriptor string section overlaps parameters");
    }
    descriptor.strings.push_back(reader.read_string(len));
  }
  if (reader.pos() > params_offset) {
    throw std::runtime_error("HashLink kernel descriptor string section overlaps parameters");
  }

  reader.seek(params_offset);
  const std::uint32_t parameter_count = reader.read_u32();
  require_section_entries_fit(reader.pos(), locals_offset, parameter_count, 8, "parameter");
  descriptor.parameters.reserve(parameter_count);
  for (std::uint32_t i = 0; i < parameter_count; ++i) {
    ParameterDescriptor param;
    param.kind = parse_parameter_kind(reader.read_u8());
    param.dtype = parse_dtype(reader.read_u8());
    param.rank = reader.read_u8();
    reader.read_u8();  // reserved
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
  if (reader.pos() > locals_offset) {
    throw std::runtime_error("HashLink kernel descriptor parameter section overlaps locals");
  }

  reader.seek(locals_offset);
  const std::uint32_t local_count = reader.read_u32();
  require_section_entries_fit(reader.pos(), statements_offset, local_count, 8, "local");
  descriptor.locals.reserve(local_count);
  for (std::uint32_t i = 0; i < local_count; ++i) {
    LocalDescriptor local;
    local.dtype = parse_dtype(reader.read_u8());
    local.allocate = reader.read_u8() != 0;
    reader.read_u8();
    reader.read_u8();
    local.name_id = reader.read_u32();
    checked_string(descriptor, local.name_id, "local name");
    descriptor.locals.push_back(local);
  }
  if (reader.pos() > statements_offset) {
    throw std::runtime_error("HashLink kernel descriptor local section overlaps statements");
  }

  reader.seek(statements_offset);
  descriptor.kernel_name_id = reader.read_u32();
  checked_string(descriptor, descriptor.kernel_name_id, "kernel name");
  const std::uint32_t statement_count = reader.read_u32();
  descriptor.statements = parse_statement_list(reader, descriptor, statement_count, 0);

  return descriptor;
}

KernelBuildResult build_kernel_from_descriptor(lang::Program &program, const KernelDescriptor &descriptor) {
  const std::string kernel_name = checked_string(descriptor, descriptor.kernel_name_id, "kernel name");

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
        kernel->finalize_rets();

        std::vector<lang::Expr> params;
        params.reserve(descriptor.parameters.size());
        for (std::size_t i = 0; i < descriptor.parameters.size(); ++i) {
          const auto &param = descriptor.parameters[i];
          lang::Expr expr;
          if (param.kind == ParameterKind::scalar) {
            expr = lang::Expr::make<lang::ArgLoadExpression>(arg_ids[i], lower_dtype(param.dtype), false, true,
                                                             lang::DebugInfo());
          } else {
            expr = lang::Expr::make<lang::ExternalTensorExpression>(lower_dtype(param.dtype), param.rank, arg_ids[i],
                                                                    false, BoundaryMode::kUnsafe);
          }
          expr.type_check(&program.compile_config());
          params.push_back(expr);
        }

        std::vector<lang::Expr> locals;
        locals.reserve(descriptor.locals.size());
        for (const auto &local : descriptor.locals) {
          lang::Expr expr = kernel->context->builder().make_id_expr(checked_string(descriptor, local.name_id, "local name"));
          expr.expr->ret_type = lower_dtype(local.dtype);
          locals.push_back(expr);
        }

        LoweringContext lowering(program, *kernel, descriptor, std::move(params), std::move(locals));
        lowering.lower_statements(descriptor.statements);
      },
      kernel_name, AutodiffMode::kNone);
  kernel_ptr = &kernel;

  lang::CompileResult compile_result = program.compile_kernel(program.compile_config(), program.get_device_caps(), kernel);
  return KernelBuildResult{kernel_ptr, &compile_result.compiled_kernel_data};
}

}  // namespace quadrants::hashlink
