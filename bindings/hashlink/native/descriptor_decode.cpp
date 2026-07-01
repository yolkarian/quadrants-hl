#include "bindings/hashlink/native/descriptor_internal.h"

#include <stdexcept>

namespace quadrants::hashlink {

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
    case DescriptorDType::u1:
    case DescriptorDType::f16:
      return static_cast<DescriptorDType>(value);
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported dtype");
}

ParameterKind parse_parameter_kind(std::uint8_t value) {
  switch (static_cast<ParameterKind>(value)) {
    case ParameterKind::scalar:
      return ParameterKind::scalar;
    case ParameterKind::ndarray:
      return ParameterKind::ndarray;
    case ParameterKind::field:
      return ParameterKind::field;
    case ParameterKind::mesh_relation:
      return ParameterKind::mesh_relation;
    case ParameterKind::mesh_attribute:
      return ParameterKind::mesh_attribute;
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported parameter kind");
}

TypeTableKind parse_type_table_kind(std::uint8_t value) {
  switch (static_cast<TypeTableKind>(value)) {
    case TypeTableKind::primitive:
      return TypeTableKind::primitive;
    case TypeTableKind::spec:
      return TypeTableKind::spec;
    case TypeTableKind::tensor_resource:
      return TypeTableKind::tensor_resource;
    case TypeTableKind::field_resource:
      return TypeTableKind::field_resource;
    case TypeTableKind::struct_tensor_resource:
      return TypeTableKind::struct_tensor_resource;
    case TypeTableKind::struct_field_resource:
      return TypeTableKind::struct_field_resource;
    case TypeTableKind::mesh_relation_resource:
      return TypeTableKind::mesh_relation_resource;
    case TypeTableKind::mesh_attribute_resource:
      return TypeTableKind::mesh_attribute_resource;
    case TypeTableKind::quant_resource:
      return TypeTableKind::quant_resource;
    case TypeTableKind::sparse_matrix_resource:
      return TypeTableKind::sparse_matrix_resource;
    case TypeTableKind::mesh_resource:
      return TypeTableKind::mesh_resource;
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported canonical type kind");
}

ArgTableKind parse_arg_table_kind(std::uint8_t value) {
  switch (static_cast<ArgTableKind>(value)) {
    case ArgTableKind::runtime_scalar:
      return ArgTableKind::runtime_scalar;
    case ArgTableKind::runtime_resource:
      return ArgTableKind::runtime_resource;
    case ArgTableKind::spec_constant:
      return ArgTableKind::spec_constant;
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported canonical arg kind");
}

ExprOpcode parse_expr_opcode(std::uint8_t value) {
  switch (static_cast<ExprOpcode>(value)) {
    case ExprOpcode::const_i32:
    case ExprOpcode::const_f64:
    case ExprOpcode::atomic_add:
    case ExprOpcode::const_i64:
    case ExprOpcode::const_u64:
    case ExprOpcode::const_f32:
    case ExprOpcode::const_bool:
    case ExprOpcode::atomic_sub:
    case ExprOpcode::atomic_min:
    case ExprOpcode::atomic_max:
    case ExprOpcode::atomic_bit_and:
    case ExprOpcode::atomic_bit_or:
    case ExprOpcode::atomic_bit_xor:
    case ExprOpcode::atomic_exchange:
    case ExprOpcode::atomic_mul:
    case ExprOpcode::atomic_compare_exchange:
    case ExprOpcode::rand:
    case ExprOpcode::thread_idx:
    case ExprOpcode::shape_axis:
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
    case ExprOpcode::binary_min:
    case ExprOpcode::binary_max:
    case ExprOpcode::binary_atan2:
    case ExprOpcode::binary_pow:
    case ExprOpcode::unary_neg:
    case ExprOpcode::unary_bit_not:
    case ExprOpcode::cast:
    case ExprOpcode::select:
    case ExprOpcode::bit_cast:
    case ExprOpcode::block_thread_idx:
    case ExprOpcode::subgroup_size:
    case ExprOpcode::subgroup_invocation_id:
    case ExprOpcode::subgroup_elect:
    case ExprOpcode::subgroup_shuffle:
    case ExprOpcode::subgroup_shuffle_down:
    case ExprOpcode::subgroup_shuffle_up:
    case ExprOpcode::subgroup_broadcast:
    case ExprOpcode::local_invocation_id:
    case ExprOpcode::global_invocation_id:
    case ExprOpcode::vk_global_thread_idx:
    case ExprOpcode::cuda_active_mask:
    case ExprOpcode::block_barrier_and:
    case ExprOpcode::block_barrier_or:
    case ExprOpcode::block_barrier_count:
    case ExprOpcode::assume_in_range:
    case ExprOpcode::volatile_load_index:
    case ExprOpcode::frexp_significand:
    case ExprOpcode::frexp_exponent:
    case ExprOpcode::fns_u32:
    case ExprOpcode::snode_append:
    case ExprOpcode::snode_length:
    case ExprOpcode::snode_is_active:
    case ExprOpcode::mesh_relation_size:
    case ExprOpcode::mesh_relation_get:
    case ExprOpcode::mesh_index_convert:
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
    case StmtOpcode::return_value:
    case StmtOpcode::atomic_min:
    case StmtOpcode::atomic_max:
    case StmtOpcode::atomic_bit_and:
    case StmtOpcode::atomic_bit_or:
    case StmtOpcode::atomic_bit_xor:
    case StmtOpcode::atomic_exchange:
    case StmtOpcode::atomic_mul:
    case StmtOpcode::loop_block_dim:
    case StmtOpcode::loop_parallelize:
    case StmtOpcode::loop_serialize:
    case StmtOpcode::print_stmt:
    case StmtOpcode::assert_stmt:
    case StmtOpcode::block_barrier:
    case StmtOpcode::block_mem_fence:
    case StmtOpcode::grid_mem_fence:
    case StmtOpcode::workgroup_barrier:
    case StmtOpcode::workgroup_memory_barrier:
    case StmtOpcode::grid_memory_barrier:
    case StmtOpcode::subgroup_barrier:
    case StmtOpcode::subgroup_memory_barrier:
    case StmtOpcode::warp_barrier:
    case StmtOpcode::struct_for_external_tensor:
    case StmtOpcode::return_values:
    case StmtOpcode::mesh_for:
    case StmtOpcode::snode_activate:
    case StmtOpcode::snode_deactivate:
      return static_cast<StmtOpcode>(value);
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported statement opcode");
}

}  // namespace quadrants::hashlink
