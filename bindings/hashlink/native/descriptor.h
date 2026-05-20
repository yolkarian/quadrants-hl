#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

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
};

enum class ParameterKind : std::uint8_t {
  scalar = 0,
  ndarray = 1,
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
};

struct ParameterDescriptor {
  ParameterKind kind{ParameterKind::scalar};
  DescriptorDType dtype{DescriptorDType::i32};
  std::uint8_t rank{0};
  std::uint32_t name_id{0};
};

struct LocalDescriptor {
  DescriptorDType dtype{DescriptorDType::i32};
  bool allocate{false};
  std::uint32_t name_id{0};
};

struct ExpressionDescriptor {
  ExprOpcode opcode{ExprOpcode::const_i32};
  std::int32_t const_i32{0};
  double const_f64{0.0};
  std::uint32_t index{0};
  DescriptorDType cast_dtype{DescriptorDType::i32};
  std::unique_ptr<ExpressionDescriptor> target;
  std::vector<std::unique_ptr<ExpressionDescriptor>> indices;
  std::unique_ptr<ExpressionDescriptor> lhs;
  std::unique_ptr<ExpressionDescriptor> rhs;
  std::unique_ptr<ExpressionDescriptor> operand;
  std::unique_ptr<ExpressionDescriptor> value;
};

struct StatementDescriptor {
  StmtOpcode opcode{StmtOpcode::return_void};
  std::uint32_t local_id{0};
  std::unique_ptr<ExpressionDescriptor> target;
  std::vector<std::unique_ptr<ExpressionDescriptor>> indices;
  std::unique_ptr<ExpressionDescriptor> value;
  std::unique_ptr<ExpressionDescriptor> begin;
  std::unique_ptr<ExpressionDescriptor> end;
  std::unique_ptr<ExpressionDescriptor> condition;
  std::vector<std::unique_ptr<StatementDescriptor>> body;
  std::vector<std::unique_ptr<StatementDescriptor>> else_body;
};

struct KernelDescriptor {
  std::vector<std::string> strings;
  std::uint32_t kernel_name_id{0};
  std::vector<ParameterDescriptor> parameters;
  std::vector<LocalDescriptor> locals;
  std::vector<std::unique_ptr<StatementDescriptor>> statements;
};

struct KernelBuildResult {
  lang::Kernel *kernel{nullptr};
  const lang::CompiledKernelData *compiled_kernel_data{nullptr};
};

KernelDescriptor decode_descriptor(const std::uint8_t *data);
KernelDescriptor decode_descriptor(const std::uint8_t *data, std::size_t size);

KernelBuildResult build_kernel_from_descriptor(lang::Program &program, const KernelDescriptor &descriptor);

}  // namespace quadrants::hashlink
