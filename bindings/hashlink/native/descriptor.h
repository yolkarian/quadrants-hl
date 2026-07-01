#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "quadrants/inc/constants.h"

namespace quadrants::lang {
class CompiledKernelData;
class Kernel;
class Program;
}  // namespace quadrants::lang

namespace quadrants::hashlink {

enum class DescriptorDType : std::uint8_t {
  i8 = 0,
  i16 = 1,
  i32 = 2,
  i64 = 3,
  u8 = 4,
  u16 = 5,
  u32 = 6,
  u64 = 7,
  f32 = 8,
  f64 = 9,
  u1 = 10,
  f16 = 11,
};

enum class ParameterKind : std::uint8_t {
  scalar = 0,
  ndarray = 1,
  field = 2,
  mesh_relation = 3,
  mesh_attribute = 4,
};

enum class ExprOpcode : std::uint8_t {
  const_i32 = 1,
  arg_load = 2,
  local_load = 3,
  load_index = 4,
  binary_add = 5,
  binary_sub = 6,
  binary_mul = 7,
  binary_div = 8,
  binary_mod = 9,
  cmp_eq = 10,
  cmp_ne = 11,
  cmp_lt = 12,
  cmp_le = 13,
  cmp_gt = 14,
  cmp_ge = 15,
  logic_and = 16,
  logic_or = 17,
  logic_not = 18,
  bit_and = 19,
  bit_or = 20,
  bit_xor = 21,
  bit_shl = 22,
  bit_shr = 23,
  bit_sar = 24,
  cast = 25,
  unary_abs = 26,
  unary_sin = 27,
  unary_cos = 28,
  unary_tan = 29,
  unary_exp = 30,
  unary_log = 31,
  unary_sqrt = 32,
  unary_floor = 33,
  unary_ceil = 34,
  binary_min = 35,
  binary_max = 36,
  select = 37,
  unary_neg = 38,
  unary_bit_not = 39,
  const_f64 = 40,
  atomic_add = 41,
  const_i64 = 42,
  const_u64 = 43,
  const_f32 = 44,
  const_bool = 45,
  unary_asin = 46,
  unary_acos = 47,
  binary_atan2 = 48,
  binary_pow = 49,
  unary_rsqrt = 50,
  unary_round = 51,
  atomic_sub = 52,
  atomic_min = 53,
  atomic_max = 54,
  atomic_bit_and = 55,
  atomic_bit_or = 56,
  atomic_bit_xor = 57,
  atomic_exchange = 58,
  thread_idx = 59,
  shape_axis = 60,
  unary_tanh = 61,
  unary_inv = 62,
  unary_rcp = 63,
  unary_popcnt = 64,
  unary_clz = 65,
  unary_ffs = 66,
  unary_sgn = 67,
  bit_cast = 68,
  atomic_mul = 69,
  block_thread_idx = 70,
  subgroup_size = 71,
  subgroup_invocation_id = 72,
  subgroup_elect = 73,
  subgroup_shuffle = 74,
  subgroup_shuffle_down = 75,
  subgroup_shuffle_up = 76,
  subgroup_broadcast = 77,
  local_invocation_id = 78,
  global_invocation_id = 79,
  vk_global_thread_idx = 80,
  cuda_active_mask = 81,
  block_barrier_and = 82,
  block_barrier_or = 83,
  block_barrier_count = 84,
  atomic_compare_exchange = 85,
  rand = 86,
  assume_in_range = 87,
  volatile_load_index = 88,
  frexp_significand = 89,
  frexp_exponent = 90,
  fns_u32 = 91,
  snode_append = 92,
  snode_length = 93,
  snode_is_active = 94,
  mesh_relation_size = 95,
  mesh_relation_get = 96,
  mesh_index_convert = 97,
};

enum class StmtOpcode : std::uint8_t {
  local_alloc = 1,
  store_index = 2,
  range_for = 3,
  if_stmt = 4,
  assign = 5,
  return_void = 6,
  while_stmt = 7,
  break_stmt = 8,
  continue_stmt = 9,
  atomic_add = 10,
  atomic_sub = 11,
  return_value = 12,
  atomic_min = 13,
  atomic_max = 14,
  atomic_bit_and = 15,
  atomic_bit_or = 16,
  atomic_bit_xor = 17,
  atomic_exchange = 18,
  atomic_mul = 19,
  loop_block_dim = 20,
  loop_parallelize = 21,
  loop_serialize = 22,
  print_stmt = 23,
  assert_stmt = 24,
  block_barrier = 25,
  block_mem_fence = 26,
  grid_mem_fence = 27,
  workgroup_barrier = 28,
  workgroup_memory_barrier = 29,
  grid_memory_barrier = 30,
  subgroup_barrier = 31,
  subgroup_memory_barrier = 32,
  warp_barrier = 33,
  struct_for_external_tensor = 34,
  return_values = 35,
  mesh_for = 36,
  snode_activate = 37,
  snode_deactivate = 38,
};

struct ParameterDescriptor {
  static constexpr std::uint8_t flag_needs_grad = 1u;
  static constexpr std::uint8_t flag_spec_constant = 2u;
  ParameterKind kind{ParameterKind::scalar};
  DescriptorDType dtype{DescriptorDType::i32};
  std::uint8_t rank{0};
  std::uint8_t flags{0};
  std::uint32_t name_id{0};

  bool needs_grad() const {
    return (flags & flag_needs_grad) != 0;
  }

  bool is_spec_constant() const {
    return (flags & flag_spec_constant) != 0;
  }
};

enum class TypeTableKind : std::uint8_t {
  primitive = 0,
  spec = 1,
  tensor_resource = 2,
  field_resource = 3,
  struct_tensor_resource = 4,
  struct_field_resource = 5,
  mesh_relation_resource = 6,
  mesh_attribute_resource = 7,
  quant_resource = 8,
  sparse_matrix_resource = 9,
  mesh_resource = 10,
};

struct TypeTableEntry {
  std::uint32_t id{0};
  TypeTableKind kind{TypeTableKind::primitive};
  DescriptorDType dtype{DescriptorDType::i32};
  std::uint8_t rank{0};
  std::uint8_t flags{0};
  std::uint32_t struct_id{0};
};

enum class ArgTableKind : std::uint8_t {
  runtime_scalar = 0,
  runtime_resource = 1,
  spec_constant = 2,
};

struct ArgTableEntry {
  std::uint32_t parameter_index{0};
  std::uint32_t type_id{0};
  std::uint32_t name_id{0};
  ArgTableKind kind{ArgTableKind::runtime_scalar};
  std::uint8_t flags{0};
};

struct ResourceTableEntry {
  std::uint32_t parameter_index{0};
  std::uint32_t type_id{0};
  std::uint32_t name_id{0};
  TypeTableKind kind{TypeTableKind::tensor_resource};
  std::uint8_t rank{0};
  std::uint8_t flags{0};
};

struct StructFieldTableEntry {
  std::uint32_t name_id{0};
  std::uint32_t type_id{0};
  std::uint32_t offset{0};
};

struct StructTableEntry {
  std::uint32_t id{0};
  std::uint32_t name_id{0};
  std::uint32_t size_bytes{0};
  std::uint32_t align_bytes{0};
  std::vector<StructFieldTableEntry> fields;
};

struct SpecTableEntry {
  std::uint32_t parameter_index{0};
  std::uint32_t type_id{0};
  std::uint32_t name_id{0};
  DescriptorDType dtype{DescriptorDType::i32};
  std::uint8_t flags{0};
};

struct SpecValue {
  DescriptorDType dtype{DescriptorDType::i32};
  std::int64_t signed_value{0};
  std::uint64_t unsigned_value{0};
  double float_value{0.0};
  bool bool_value{false};
};

struct MeshRelationSpecialization {
  bool present{false};
  std::uint8_t from_type{0};
  std::uint8_t to_type{0};
  bool fixed{false};
  std::uint32_t fixed_degree{0};
  std::array<std::uint32_t, 4> counts{};
  std::array<int, 4> owned_offset_snode_ids{{-1, -1, -1, -1}};
  std::array<int, 4> total_offset_snode_ids{{-1, -1, -1, -1}};
  std::array<int, 12> index_mapping_snode_ids{{-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1}};
  int value_snode_id{-1};
  int offset_snode_id{-1};
  int patch_offset_snode_id{-1};
};

struct LocalDescriptor {
  DescriptorDType dtype{DescriptorDType::i32};
  bool allocate{false};
  std::uint32_t name_id{0};
  std::uint32_t shared_size{0};
};

struct SourceSpanDescriptor {
  std::uint32_t file_name_id{0};
  std::uint32_t line{0};
  std::uint32_t begin{0};
  std::uint32_t end{0};
};


struct ExpressionDescriptor {
  ExprOpcode opcode{ExprOpcode::const_i32};
  std::int32_t const_i32{0};
  double const_f64{0.0};
  std::int64_t const_i64{0};
  std::uint64_t const_u64{0};
  float const_f32{0.0f};
  bool const_bool{false};
  std::uint32_t index{0};
  std::uint32_t axis{0};
  DescriptorDType cast_dtype{DescriptorDType::i32};
  std::int32_t range_low{0};
  std::int32_t range_high{0};
  std::unique_ptr<ExpressionDescriptor> target;
  std::vector<std::unique_ptr<ExpressionDescriptor>> indices;
  std::unique_ptr<ExpressionDescriptor> lhs;
  std::unique_ptr<ExpressionDescriptor> rhs;
  std::unique_ptr<ExpressionDescriptor> operand;
  std::unique_ptr<ExpressionDescriptor> value;
  std::unique_ptr<ExpressionDescriptor> expected;
};

struct StatementDescriptor {
  StmtOpcode opcode{StmtOpcode::return_void};
  std::uint32_t local_id{0};
  std::uint32_t hint_value{0};
  std::uint8_t mesh_element_type{0};
  std::array<std::uint32_t, 4> mesh_num_elements{};
  bool print_value{false};
  bool has_message{false};
  std::string message;
  std::unique_ptr<ExpressionDescriptor> target;
  std::vector<std::unique_ptr<ExpressionDescriptor>> indices;
  std::unique_ptr<ExpressionDescriptor> value;
  std::vector<std::unique_ptr<ExpressionDescriptor>> values;
  std::unique_ptr<ExpressionDescriptor> begin;
  std::unique_ptr<ExpressionDescriptor> end;
  std::unique_ptr<ExpressionDescriptor> condition;
  std::vector<std::unique_ptr<StatementDescriptor>> body;
  std::vector<std::unique_ptr<StatementDescriptor>> else_body;
};

struct FunctionDescriptor {
  std::uint32_t name_id{0};
  bool has_return{false};
  DescriptorDType return_dtype{DescriptorDType::i32};
  std::vector<ParameterDescriptor> parameters;
};

struct KernelDescriptor {
  std::vector<std::string> strings;
  std::uint32_t kernel_name_id{0};
  bool has_return{false};
  DescriptorDType return_dtype{DescriptorDType::i32};
  std::vector<ParameterDescriptor> parameters;
  std::vector<DescriptorDType> return_dtypes;
  std::vector<TypeTableEntry> type_table;
  std::vector<ArgTableEntry> arg_table;
  std::vector<ResourceTableEntry> resource_table;
  std::vector<StructTableEntry> struct_table;
  std::vector<SpecTableEntry> spec_table;
  std::vector<LocalDescriptor> locals;
  std::vector<std::unique_ptr<StatementDescriptor>> statements;
  std::vector<SourceSpanDescriptor> source_spans;
  std::vector<FunctionDescriptor> functions;
};

struct KernelBuildResult {
  lang::Kernel *kernel{nullptr};
  const lang::CompiledKernelData *compiled_kernel_data{nullptr};
};

KernelDescriptor decode_descriptor(const std::uint8_t *data);
KernelDescriptor decode_descriptor(const std::uint8_t *data, std::size_t size);

AutodiffMode autodiff_mode_from_bridge_id(int mode);

KernelBuildResult build_kernel_from_descriptor(lang::Program &program,
                                              const KernelDescriptor &descriptor,
                                              AutodiffMode autodiff_mode,
                                              const std::vector<int> *field_snode_ids = nullptr,
                                              const std::vector<int> *field_adjoint_snode_ids = nullptr,
                                              const std::vector<int> *field_dual_snode_ids = nullptr,
                                              const std::vector<SpecValue> *spec_values = nullptr,
                                              const std::vector<MeshRelationSpecialization> *mesh_relations = nullptr);

}  // namespace quadrants::hashlink
