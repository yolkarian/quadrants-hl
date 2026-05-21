#pragma once

#include <cstdint>

#include "bindings/hashlink/native/descriptor.h"
#include "quadrants/ir/stmt_op_types.h"
#include "quadrants/ir/type.h"
#include "quadrants/ir/type_system.h"

namespace quadrants::hashlink {

DescriptorDType parse_dtype(std::uint8_t value);
lang::DataType lower_dtype(DescriptorDType dtype);
ParameterKind parse_parameter_kind(std::uint8_t value);
ExprOpcode parse_expr_opcode(std::uint8_t value);
StmtOpcode parse_stmt_opcode(std::uint8_t value);

void validate_descriptor(const KernelDescriptor &descriptor);

lang::UnaryOpType lower_unary_opcode(ExprOpcode opcode);
lang::BinaryOpType lower_binary_opcode(ExprOpcode opcode);
lang::AtomicOpType lower_atomic_expr_opcode(ExprOpcode opcode);
lang::AtomicOpType lower_atomic_stmt_opcode(StmtOpcode opcode);
lang::InternalOp lower_internal_expr_opcode(ExprOpcode opcode);
lang::InternalOp lower_internal_stmt_opcode(StmtOpcode opcode);

}  // namespace quadrants::hashlink
