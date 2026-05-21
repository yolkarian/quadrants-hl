#include "bindings/hashlink/native/descriptor_internal.h"

#include <stdexcept>

namespace quadrants::hashlink {

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
    case DescriptorDType::u1:
      return lang::PrimitiveType::u1;
    case DescriptorDType::f16:
      return lang::PrimitiveType::f16;
  }
  throw std::runtime_error("HashLink kernel descriptor uses an unsupported dtype");
}

}  // namespace quadrants::hashlink
