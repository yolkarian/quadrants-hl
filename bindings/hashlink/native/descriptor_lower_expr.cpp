#include "bindings/hashlink/native/descriptor_internal.h"

#include <stdexcept>

namespace quadrants::hashlink {

lang::UnaryOpType lower_unary_opcode(ExprOpcode opcode) {
  switch (opcode) {
    case ExprOpcode::logic_not: return lang::UnaryOpType::logic_not;
    case ExprOpcode::unary_abs: return lang::UnaryOpType::abs;
    case ExprOpcode::unary_sin: return lang::UnaryOpType::sin;
    case ExprOpcode::unary_cos: return lang::UnaryOpType::cos;
    case ExprOpcode::unary_tan: return lang::UnaryOpType::tan;
    case ExprOpcode::unary_exp: return lang::UnaryOpType::exp;
    case ExprOpcode::unary_log: return lang::UnaryOpType::log;
    case ExprOpcode::unary_sqrt: return lang::UnaryOpType::sqrt;
    case ExprOpcode::unary_floor: return lang::UnaryOpType::floor;
    case ExprOpcode::unary_ceil: return lang::UnaryOpType::ceil;
    case ExprOpcode::unary_asin: return lang::UnaryOpType::asin;
    case ExprOpcode::unary_acos: return lang::UnaryOpType::acos;
    case ExprOpcode::unary_rsqrt: return lang::UnaryOpType::rsqrt;
    case ExprOpcode::unary_round: return lang::UnaryOpType::round;
    case ExprOpcode::unary_tanh: return lang::UnaryOpType::tanh;
    case ExprOpcode::unary_inv: return lang::UnaryOpType::inv;
    case ExprOpcode::unary_rcp: return lang::UnaryOpType::rcp;
    case ExprOpcode::unary_popcnt: return lang::UnaryOpType::popcnt;
    case ExprOpcode::unary_clz: return lang::UnaryOpType::clz;
    case ExprOpcode::unary_ffs: return lang::UnaryOpType::ffs;
    case ExprOpcode::unary_sgn: return lang::UnaryOpType::sgn;
    case ExprOpcode::unary_neg: return lang::UnaryOpType::neg;
    case ExprOpcode::unary_bit_not: return lang::UnaryOpType::bit_not;
    default: break;
  }
  throw std::runtime_error("HashLink kernel descriptor expression is not a unary operation");
}

lang::BinaryOpType lower_binary_opcode(ExprOpcode opcode) {
  switch (opcode) {
    case ExprOpcode::binary_add: return lang::BinaryOpType::add;
    case ExprOpcode::binary_sub: return lang::BinaryOpType::sub;
    case ExprOpcode::binary_mul: return lang::BinaryOpType::mul;
    case ExprOpcode::binary_div: return lang::BinaryOpType::div;
    case ExprOpcode::binary_mod: return lang::BinaryOpType::mod;
    case ExprOpcode::cmp_eq: return lang::BinaryOpType::cmp_eq;
    case ExprOpcode::cmp_ne: return lang::BinaryOpType::cmp_ne;
    case ExprOpcode::cmp_lt: return lang::BinaryOpType::cmp_lt;
    case ExprOpcode::cmp_le: return lang::BinaryOpType::cmp_le;
    case ExprOpcode::cmp_gt: return lang::BinaryOpType::cmp_gt;
    case ExprOpcode::cmp_ge: return lang::BinaryOpType::cmp_ge;
    case ExprOpcode::logic_and: return lang::BinaryOpType::logical_and;
    case ExprOpcode::logic_or: return lang::BinaryOpType::logical_or;
    case ExprOpcode::bit_and: return lang::BinaryOpType::bit_and;
    case ExprOpcode::bit_or: return lang::BinaryOpType::bit_or;
    case ExprOpcode::bit_xor: return lang::BinaryOpType::bit_xor;
    case ExprOpcode::bit_shl: return lang::BinaryOpType::bit_shl;
    case ExprOpcode::bit_shr: return lang::BinaryOpType::bit_shr;
    case ExprOpcode::bit_sar: return lang::BinaryOpType::bit_sar;
    case ExprOpcode::binary_min: return lang::BinaryOpType::min;
    case ExprOpcode::binary_max: return lang::BinaryOpType::max;
    case ExprOpcode::binary_atan2: return lang::BinaryOpType::atan2;
    case ExprOpcode::binary_pow: return lang::BinaryOpType::pow;
    default: break;
  }
  throw std::runtime_error("HashLink kernel descriptor expression is not a binary operation");
}

lang::AtomicOpType lower_atomic_expr_opcode(ExprOpcode opcode) {
  switch (opcode) {
    case ExprOpcode::atomic_add: return lang::AtomicOpType::add;
    case ExprOpcode::atomic_sub: return lang::AtomicOpType::sub;
    case ExprOpcode::atomic_min: return lang::AtomicOpType::min;
    case ExprOpcode::atomic_max: return lang::AtomicOpType::max;
    case ExprOpcode::atomic_bit_and: return lang::AtomicOpType::bit_and;
    case ExprOpcode::atomic_bit_or: return lang::AtomicOpType::bit_or;
    case ExprOpcode::atomic_bit_xor: return lang::AtomicOpType::bit_xor;
    case ExprOpcode::atomic_exchange: return lang::AtomicOpType::xchg;
    case ExprOpcode::atomic_mul: return lang::AtomicOpType::mul;
    case ExprOpcode::atomic_compare_exchange: return lang::AtomicOpType::cas;
    default: break;
  }
  throw std::runtime_error("HashLink kernel descriptor expression is not an atomic operation");
}

lang::InternalOp lower_internal_expr_opcode(ExprOpcode opcode) {
  switch (opcode) {
    case ExprOpcode::block_thread_idx: return lang::InternalOp::block_thread_idx;
    case ExprOpcode::subgroup_size: return lang::InternalOp::subgroupSize;
    case ExprOpcode::subgroup_invocation_id: return lang::InternalOp::subgroupInvocationId;
    case ExprOpcode::subgroup_elect: return lang::InternalOp::subgroupElect;
    case ExprOpcode::subgroup_shuffle: return lang::InternalOp::subgroupShuffle;
    case ExprOpcode::subgroup_shuffle_down: return lang::InternalOp::subgroupShuffleDown;
    case ExprOpcode::subgroup_shuffle_up: return lang::InternalOp::subgroupShuffleUp;
    case ExprOpcode::subgroup_broadcast: return lang::InternalOp::subgroupBroadcast;
    case ExprOpcode::local_invocation_id: return lang::InternalOp::localInvocationId;
    case ExprOpcode::global_invocation_id: return lang::InternalOp::globalInvocationId;
    case ExprOpcode::vk_global_thread_idx: return lang::InternalOp::vkGlobalThreadIdx;
    case ExprOpcode::cuda_active_mask: return lang::InternalOp::cuda_active_mask;
    case ExprOpcode::block_barrier_and: return lang::InternalOp::block_barrier_and_i32;
    case ExprOpcode::block_barrier_or: return lang::InternalOp::block_barrier_or_i32;
    case ExprOpcode::block_barrier_count: return lang::InternalOp::block_barrier_count_i32;
    default: break;
  }
  throw std::runtime_error("HashLink kernel descriptor expression is not an internal operation");
}

}  // namespace quadrants::hashlink
