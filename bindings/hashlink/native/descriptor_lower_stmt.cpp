#include "bindings/hashlink/native/descriptor_internal.h"

#include <stdexcept>

namespace quadrants::hashlink {

lang::AtomicOpType lower_atomic_stmt_opcode(StmtOpcode opcode) {
  switch (opcode) {
    case StmtOpcode::atomic_add: return lang::AtomicOpType::add;
    case StmtOpcode::atomic_sub: return lang::AtomicOpType::sub;
    case StmtOpcode::atomic_min: return lang::AtomicOpType::min;
    case StmtOpcode::atomic_max: return lang::AtomicOpType::max;
    case StmtOpcode::atomic_bit_and: return lang::AtomicOpType::bit_and;
    case StmtOpcode::atomic_bit_or: return lang::AtomicOpType::bit_or;
    case StmtOpcode::atomic_bit_xor: return lang::AtomicOpType::bit_xor;
    case StmtOpcode::atomic_exchange: return lang::AtomicOpType::xchg;
    case StmtOpcode::atomic_mul: return lang::AtomicOpType::mul;
    default: break;
  }
  throw std::runtime_error("HashLink kernel descriptor statement is not an atomic operation");
}

lang::InternalOp lower_internal_stmt_opcode(StmtOpcode opcode) {
  switch (opcode) {
    case StmtOpcode::block_barrier: return lang::InternalOp::block_barrier;
    case StmtOpcode::block_mem_fence: return lang::InternalOp::block_mem_fence;
    case StmtOpcode::grid_mem_fence: return lang::InternalOp::grid_mem_fence;
    case StmtOpcode::workgroup_barrier: return lang::InternalOp::workgroupBarrier;
    case StmtOpcode::workgroup_memory_barrier: return lang::InternalOp::workgroupMemoryBarrier;
    case StmtOpcode::grid_memory_barrier: return lang::InternalOp::gridMemoryBarrier;
    case StmtOpcode::subgroup_barrier: return lang::InternalOp::subgroupBarrier;
    case StmtOpcode::subgroup_memory_barrier: return lang::InternalOp::subgroupMemoryBarrier;
    case StmtOpcode::warp_barrier: return lang::InternalOp::warp_barrier;
    default: break;
  }
  throw std::runtime_error("HashLink kernel descriptor statement is not an internal operation");
}

}  // namespace quadrants::hashlink
