#include "bindings/hashlink/native/quadrants_hl.h"

#include <atomic>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <limits>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <vector>

#include "bindings/hashlink/native/descriptor.h"
#include "quadrants/ir/type.h"
#include "quadrants/program/kernel.h"
#include "quadrants/program/launch_context_builder.h"
#include "quadrants/program/ndarray.h"
#include "quadrants/program/program.h"
#include "quadrants/rhi/arch.h"

namespace {

using quadrants::Arch;
using quadrants::host_arch;
using quadrants::hashlink::DescriptorDType;
using quadrants::hashlink::ParameterKind;
using quadrants::lang::CompiledKernelData;
using quadrants::lang::Kernel;
using quadrants::lang::LaunchContextBuilder;
using quadrants::lang::Ndarray;
using quadrants::lang::PrimitiveType;
using quadrants::lang::PrimitiveTypeID;
using quadrants::lang::Program;

struct QdContextState {
  explicit QdContextState(Arch arch) : program(std::make_unique<Program>(arch)), arch(arch) {
    program->materialize_runtime();
  }

  std::unique_ptr<Program> program;
  Arch arch;
  std::atomic<int> refs{1};
  bool closed{false};
};


[[noreturn]] void throw_hl_error(const std::string &message) {
  hl_buffer *buffer = hl_alloc_buffer();
  hl_buffer_cstr(buffer, message.c_str());
  hl_throw_buffer(buffer);
  std::abort();
}

template <typename Fn>
auto guard(Fn &&fn) -> decltype(fn()) {
  try {
    return fn();
  } catch (const std::exception &e) {
    throw_hl_error(e.what());
  } catch (...) {
    throw_hl_error("Unknown native Quadrants HashLink bridge error");
  }
}

class BlockingSection {
 public:
  BlockingSection() {
    hl_blocking(true);
  }

  ~BlockingSection() {
    hl_blocking(false);
  }
};

void retain_state(QdContextState *state) {
  if (state == nullptr) {
    throw std::runtime_error("Quadrants context state is null");
  }
  state->refs.fetch_add(1, std::memory_order_relaxed);
}

void release_state(QdContextState *state) noexcept {
  if (state != nullptr && state->refs.fetch_sub(1, std::memory_order_acq_rel) == 1) {
    delete state;
  }
}

void close_state(QdContextState *state) {
  if (state == nullptr || state->closed) {
    return;
  }
  if (state->program) {
    state->program->finalize();
    state->program.reset();
  }
  state->closed = true;
}

void close_state_noexcept(QdContextState *state) noexcept {
  try {
    close_state(state);
  } catch (...) {
  }
}

Arch arch_from_bridge_id(int arch) {
  switch (arch) {
    case 0:
      return host_arch();
    case 1:
      return Arch::cuda;
    case 2:
      return Arch::vulkan;
    case 3:
      return Arch::metal;
    case 4:
      return Arch::amdgpu;
    default:
      throw std::runtime_error("Unsupported Quadrants HashLink arch id: " + std::to_string(arch));
  }
}

quadrants::lang::DataType dtype_from_bridge_id(int dtype) {
  switch (dtype) {
    case 0:
      return PrimitiveType::i8;
    case 1:
      return PrimitiveType::i16;
    case 2:
      return PrimitiveType::i32;
    case 3:
      return PrimitiveType::i64;
    case 4:
      return PrimitiveType::u8;
    case 5:
      return PrimitiveType::u16;
    case 6:
      return PrimitiveType::u32;
    case 7:
      return PrimitiveType::u64;
    case 8:
      return PrimitiveType::f32;
    case 9:
      return PrimitiveType::f64;
    default:
      throw std::runtime_error("Unsupported Quadrants HashLink dtype id: " + std::to_string(dtype));
  }
}

PrimitiveTypeID primitive_id_from_descriptor_dtype(DescriptorDType dtype) {
  switch (dtype) {
    case DescriptorDType::i8:
      return PrimitiveTypeID::i8;
    case DescriptorDType::i16:
      return PrimitiveTypeID::i16;
    case DescriptorDType::i32:
      return PrimitiveTypeID::i32;
    case DescriptorDType::i64:
      return PrimitiveTypeID::i64;
    case DescriptorDType::u8:
      return PrimitiveTypeID::u8;
    case DescriptorDType::u16:
      return PrimitiveTypeID::u16;
    case DescriptorDType::u32:
      return PrimitiveTypeID::u32;
    case DescriptorDType::u64:
      return PrimitiveTypeID::u64;
    case DescriptorDType::f32:
      return PrimitiveTypeID::f32;
    case DescriptorDType::f64:
      return PrimitiveTypeID::f64;
  }
  throw std::runtime_error("Unsupported Quadrants HashLink descriptor dtype");
}

const char *dtype_name(PrimitiveTypeID dtype) {
  switch (dtype) {
    case PrimitiveTypeID::i8:
      return "i8";
    case PrimitiveTypeID::i16:
      return "i16";
    case PrimitiveTypeID::i32:
      return "i32";
    case PrimitiveTypeID::i64:
      return "i64";
    case PrimitiveTypeID::u8:
      return "u8";
    case PrimitiveTypeID::u16:
      return "u16";
    case PrimitiveTypeID::u32:
      return "u32";
    case PrimitiveTypeID::u64:
      return "u64";
    case PrimitiveTypeID::f32:
      return "f32";
    case PrimitiveTypeID::f64:
      return "f64";
    default:
      return "unsupported";
  }
}

std::vector<int> shape_from_hl_array(varray *shape) {
  if (shape == nullptr) {
    throw std::runtime_error("Quadrants ndarray shape is null");
  }
  if (shape->size <= 0) {
    throw std::runtime_error("Quadrants ndarray shape must have at least one dimension");
  }
  int *items = hl_aptr(shape, int);
  std::vector<int> result;
  result.reserve(shape->size);
  for (int i = 0; i < shape->size; ++i) {
    if (items[i] <= 0) {
      throw std::runtime_error("Quadrants ndarray shape dimensions must be positive");
    }
    result.push_back(items[i]);
  }
  return result;
}

std::vector<int> flat_to_indices(const Ndarray &array, int flat_index) {
  if (flat_index < 0) {
    throw std::runtime_error("Quadrants ndarray flat index is negative");
  }
  std::size_t remaining = static_cast<std::size_t>(flat_index);
  const std::size_t total = array.get_nelement();
  if (remaining >= total) {
    throw std::runtime_error("Quadrants ndarray flat index is out of bounds");
  }
  std::vector<int> indices(array.shape.size(), 0);
  for (std::size_t i = array.shape.size(); i > 0; --i) {
    const std::size_t axis = i - 1;
    const int dim = array.shape[axis];
    indices[axis] = static_cast<int>(remaining % static_cast<std::size_t>(dim));
    remaining /= static_cast<std::size_t>(dim);
  }
  return indices;
}

void require_array_dtype(const Ndarray &array, PrimitiveTypeID dtype) {
  if (!array.get_element_data_type()->is_primitive(dtype)) {
    throw std::runtime_error(std::string("Quadrants ndarray dtype mismatch; expected ") + dtype_name(dtype));
  }
}

std::uint32_t i32_bits(int value) {
  std::uint32_t bits = 0;
  static_assert(sizeof(bits) == sizeof(value));
  std::memcpy(&bits, &value, sizeof(bits));
  return bits;
}

}  // namespace

struct qd_context {
  void (*finalize)(qd_context *self){nullptr};
  QdContextState *state{nullptr};
  bool released{false};
};

struct qd_kernel {
  void (*finalize)(qd_kernel *self){nullptr};
  QdContextState *state{nullptr};
  Kernel *kernel{nullptr};
  const CompiledKernelData *compiled_kernel_data{nullptr};
  std::vector<quadrants::hashlink::ParameterDescriptor> parameters;
  bool released{false};
};

struct qd_ndarray {
  void (*finalize)(qd_ndarray *self){nullptr};
  QdContextState *state{nullptr};
  Ndarray *array{nullptr};
  bool released{false};
};

namespace {
void release_context_handle(qd_context *ctx) noexcept {
  if (ctx == nullptr || ctx->released) {
    return;
  }
  close_state_noexcept(ctx->state);
  release_state(ctx->state);
  ctx->state = nullptr;
  ctx->released = true;
}

void release_kernel_handle(qd_kernel *kernel) noexcept {
  if (kernel == nullptr || kernel->released) {
    return;
  }
  kernel->kernel = nullptr;
  kernel->compiled_kernel_data = nullptr;
  release_state(kernel->state);
  kernel->state = nullptr;
  kernel->released = true;
}

void release_ndarray_handle(qd_ndarray *array) noexcept {
  if (array == nullptr || array->released) {
    return;
  }
  if (array->state != nullptr && array->state->program != nullptr && array->array != nullptr) {
    try {
      array->state->program->delete_ndarray(array->array);
    } catch (...) {
    }
  }
  array->array = nullptr;
  release_state(array->state);
  array->state = nullptr;
  array->released = true;
}

void finalize_context(qd_context *ctx) {
  release_context_handle(ctx);
  ctx->~qd_context();
}

void finalize_kernel(qd_kernel *kernel) {
  release_kernel_handle(kernel);
  kernel->~qd_kernel();
}

void finalize_ndarray(qd_ndarray *array) {
  release_ndarray_handle(array);
  array->~qd_ndarray();
}

QdContextState &require_context(qd_context *ctx) {
  if (ctx == nullptr || ctx->state == nullptr || ctx->released) {
    throw std::runtime_error("Quadrants context handle is closed");
  }
  if (ctx->state->program == nullptr || ctx->state->closed) {
    throw std::runtime_error("Quadrants context is closed");
  }
  return *ctx->state;
}

Ndarray &require_ndarray(QdContextState &state, qd_ndarray *array) {
  if (array == nullptr || array->state == nullptr || array->released || array->array == nullptr) {
    throw std::runtime_error("Quadrants ndarray handle is closed");
  }
  if (array->state != &state) {
    throw std::runtime_error("Quadrants ndarray belongs to a different context");
  }
  return *array->array;
}

qd_ndarray *dynamic_to_ndarray(vdynamic *value) {
  if (value == nullptr) {
    throw std::runtime_error("Quadrants kernel ndarray argument is null");
  }
  if (value->t == nullptr || value->t->kind != HABSTRACT || ucmp(value->t->abs_name, USTR("qd_ndarray")) != 0) {
    throw std::runtime_error("Quadrants kernel ndarray argument must be a quadrants.Tensor");
  }
  return static_cast<qd_ndarray *>(value->v.ptr);
}

Kernel &require_kernel(QdContextState &state, qd_kernel *kernel) {
  if (kernel == nullptr || kernel->state == nullptr || kernel->released || kernel->kernel == nullptr ||
      kernel->compiled_kernel_data == nullptr) {
    throw std::runtime_error("Quadrants kernel handle is closed");
  }
  if (kernel->state != &state) {
    throw std::runtime_error("Quadrants kernel belongs to a different context");
  }
  return *kernel->kernel;
}

Ndarray &require_typed_ndarray(QdContextState &state, qd_ndarray *array, PrimitiveTypeID dtype) {
  Ndarray &ndarray = require_ndarray(state, array);
  require_array_dtype(ndarray, dtype);
  return ndarray;
}

void require_flat_fill_supported(const Ndarray &array) {
  if (array.get_nelement() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
    throw std::runtime_error("Quadrants ndarray is too large for HashLink host fill");
  }
}

void fill_ndarray_int(QdContextState &state, qd_ndarray *arr, PrimitiveTypeID dtype, int64 value) {
  Ndarray &array = require_typed_ndarray(state, arr, dtype);
  require_flat_fill_supported(array);
  for (std::size_t i = 0; i < array.get_nelement(); ++i) {
    array.write_int(flat_to_indices(array, static_cast<int>(i)), value);
  }
}

void fill_ndarray_float(QdContextState &state, qd_ndarray *arr, PrimitiveTypeID dtype, double value) {
  Ndarray &array = require_typed_ndarray(state, arr, dtype);
  require_flat_fill_supported(array);
  for (std::size_t i = 0; i < array.get_nelement(); ++i) {
    array.write_float(flat_to_indices(array, static_cast<int>(i)), value);
  }
}

void set_scalar_arg(LaunchContextBuilder &launch_context, int arg_id, DescriptorDType dtype, vdynamic *value) {
  switch (dtype) {
    case DescriptorDType::i8:
    case DescriptorDType::i16:
    case DescriptorDType::i32:
      launch_context.set_arg_int(arg_id, hl_dyn_casti(&value, &hlt_dyn, &hlt_i32));
      return;
    case DescriptorDType::i64:
      launch_context.set_arg_int(arg_id, hl_dyn_casti64(&value, &hlt_dyn));
      return;
    case DescriptorDType::u8:
    case DescriptorDType::u16:
      launch_context.set_arg_uint(arg_id, static_cast<uint64>(hl_dyn_casti(&value, &hlt_dyn, &hlt_i32)));
      return;
    case DescriptorDType::u32:
    case DescriptorDType::u64:
      launch_context.set_arg_uint(arg_id, static_cast<uint64>(hl_dyn_casti64(&value, &hlt_dyn)));
      return;
    case DescriptorDType::f32:
    case DescriptorDType::f64:
      launch_context.set_arg_float(arg_id, hl_dyn_castd(&value, &hlt_dyn));
      return;
  }
  throw std::runtime_error("Unsupported Quadrants HashLink scalar dtype");
}

}  // namespace

HL_PRIM qd_context *HL_NAME(context_create)(int arch) {
  return guard([&]() -> qd_context * {
    BlockingSection blocking;
    auto *state = new QdContextState(arch_from_bridge_id(arch));
    auto *handle = static_cast<qd_context *>(hl_gc_alloc_finalizer(sizeof(qd_context)));
    new (handle) qd_context();
    handle->finalize = finalize_context;
    handle->state = state;
    return handle;
  });
}

HL_PRIM void HL_NAME(context_sync)(qd_context *ctx) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    BlockingSection blocking;
    state.program->synchronize_and_assert();
  });
}

HL_PRIM void HL_NAME(context_close)(qd_context *ctx) {
  guard([&]() {
    BlockingSection blocking;
    release_context_handle(ctx);
  });
}

HL_PRIM qd_ndarray *HL_NAME(ndarray_create)(qd_context *ctx, int dtype, varray *shape) {
  return guard([&]() -> qd_ndarray * {
    QdContextState &state = require_context(ctx);
    std::vector<int> dims = shape_from_hl_array(shape);
    Ndarray *array = state.program->create_ndarray(dtype_from_bridge_id(dtype), dims);

    auto *handle = static_cast<qd_ndarray *>(hl_gc_alloc_finalizer(sizeof(qd_ndarray)));
    new (handle) qd_ndarray();
    handle->finalize = finalize_ndarray;
    handle->state = &state;
    handle->array = array;
    retain_state(&state);
    return handle;
  });
}

HL_PRIM void HL_NAME(ndarray_fill_i8)(qd_context *ctx, qd_ndarray *arr, int value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::i8, value); });
}

HL_PRIM int HL_NAME(ndarray_read_i8)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i8);
    return static_cast<int>(array.read_int(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_i8)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i8);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_i16)(qd_context *ctx, qd_ndarray *arr, int value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::i16, value); });
}

HL_PRIM int HL_NAME(ndarray_read_i16)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i16);
    return static_cast<int>(array.read_int(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_i16)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i16);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_i32)(qd_context *ctx, qd_ndarray *arr, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i32);
    state.program->fill_ndarray_fast_u32(&array, i32_bits(value));
  });
}

HL_PRIM int HL_NAME(ndarray_read_i32)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i32);
    return static_cast<int>(array.read_int(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_i32)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i32);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_i64)(qd_context *ctx, qd_ndarray *arr, int64 value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::i64, value); });
}

HL_PRIM int64 HL_NAME(ndarray_read_i64)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int64 {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i64);
    return static_cast<int64>(array.read_int(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_i64)(qd_context *ctx, qd_ndarray *arr, int flat_index, int64 value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::i64);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_u8)(qd_context *ctx, qd_ndarray *arr, int value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::u8, value); });
}

HL_PRIM int HL_NAME(ndarray_read_u8)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u8);
    return static_cast<int>(array.read_uint(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_u8)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u8);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_u16)(qd_context *ctx, qd_ndarray *arr, int value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::u16, value); });
}

HL_PRIM int HL_NAME(ndarray_read_u16)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u16);
    return static_cast<int>(array.read_uint(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_u16)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u16);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_u32)(qd_context *ctx, qd_ndarray *arr, int64 value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::u32, value); });
}

HL_PRIM int64 HL_NAME(ndarray_read_u32)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int64 {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u32);
    return static_cast<int64>(array.read_uint(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_u32)(qd_context *ctx, qd_ndarray *arr, int flat_index, int64 value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u32);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_u64)(qd_context *ctx, qd_ndarray *arr, int64 value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::u64, value); });
}

HL_PRIM int64 HL_NAME(ndarray_read_u64)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int64 {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u64);
    return static_cast<int64>(array.read_uint(flat_to_indices(array, flat_index)));
  });
}

HL_PRIM void HL_NAME(ndarray_write_u64)(qd_context *ctx, qd_ndarray *arr, int flat_index, int64 value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u64);
    array.write_int(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_f32)(qd_context *ctx, qd_ndarray *arr, double value) {
  guard([&]() { fill_ndarray_float(require_context(ctx), arr, PrimitiveTypeID::f32, value); });
}

HL_PRIM double HL_NAME(ndarray_read_f32)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f32);
    return array.read_float(flat_to_indices(array, flat_index));
  });
}

HL_PRIM void HL_NAME(ndarray_write_f32)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f32);
    array.write_float(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM void HL_NAME(ndarray_fill_f64)(qd_context *ctx, qd_ndarray *arr, double value) {
  guard([&]() { fill_ndarray_float(require_context(ctx), arr, PrimitiveTypeID::f64, value); });
}

HL_PRIM double HL_NAME(ndarray_read_f64)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f64);
    return array.read_float(flat_to_indices(array, flat_index));
  });
}

HL_PRIM void HL_NAME(ndarray_write_f64)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f64);
    array.write_float(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM qd_kernel *HL_NAME(kernel_compile)(qd_context *ctx, vbyte *descriptor_bytes, int descriptor_length) {
  return guard([&]() -> qd_kernel * {
    QdContextState &state = require_context(ctx);
    if (descriptor_length < 0) {
      throw std::runtime_error("HashLink kernel descriptor length is negative");
    }
    BlockingSection blocking;
    quadrants::hashlink::KernelDescriptor descriptor = quadrants::hashlink::decode_descriptor(
        reinterpret_cast<const std::uint8_t *>(descriptor_bytes), static_cast<std::size_t>(descriptor_length));
    quadrants::hashlink::KernelBuildResult result = quadrants::hashlink::build_kernel_from_descriptor(*state.program,
                                                                                                      descriptor);

    auto *handle = static_cast<qd_kernel *>(hl_gc_alloc_finalizer(sizeof(qd_kernel)));
    new (handle) qd_kernel();
    handle->finalize = finalize_kernel;
    handle->state = &state;
    handle->kernel = result.kernel;
    handle->compiled_kernel_data = result.compiled_kernel_data;
    handle->parameters = descriptor.parameters;
    retain_state(&state);
    return handle;
  });
}

HL_PRIM void HL_NAME(kernel_launch)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    if (args == nullptr) {
      throw std::runtime_error("Quadrants kernel argument array is null");
    }
    if (args->size != static_cast<int>(kernel->parameters.size())) {
      throw std::runtime_error("Quadrants kernel argument count mismatch");
    }

    vdynamic **values = hl_aptr(args, vdynamic *);
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    for (std::size_t i = 0; i < kernel->parameters.size(); ++i) {
      const auto &param = kernel->parameters[i];
      if (param.kind == ParameterKind::scalar) {
        if (values[i] == nullptr) {
          throw std::runtime_error("Quadrants scalar kernel argument is null");
        }
        set_scalar_arg(launch_context, static_cast<int>(i), param.dtype, values[i]);
      } else {
        qd_ndarray *array_handle = dynamic_to_ndarray(values[i]);
        Ndarray &array = require_ndarray(state, array_handle);
        if (param.rank != array.shape.size()) {
          throw std::runtime_error("Quadrants ndarray kernel argument rank mismatch");
        }
        require_array_dtype(array, primitive_id_from_descriptor_dtype(param.dtype));
        launch_context.set_arg_ndarray(static_cast<int>(i), array);
      }
    }

    BlockingSection blocking;
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_close)(qd_kernel *kernel) {
  guard([&]() { release_kernel_handle(kernel); });
}

DEFINE_PRIM(_QD_CONTEXT, context_create, _I32);
DEFINE_PRIM(_VOID, context_sync, _QD_CONTEXT);
DEFINE_PRIM(_VOID, context_close, _QD_CONTEXT);

DEFINE_PRIM(_QD_NDARRAY, ndarray_create, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, ndarray_fill_i8, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_I32, ndarray_read_i8, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_i8, _QD_CONTEXT _QD_NDARRAY _I32 _I32);
DEFINE_PRIM(_VOID, ndarray_fill_i16, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_I32, ndarray_read_i16, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_i16, _QD_CONTEXT _QD_NDARRAY _I32 _I32);
DEFINE_PRIM(_VOID, ndarray_fill_i32, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_I32, ndarray_read_i32, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_i32, _QD_CONTEXT _QD_NDARRAY _I32 _I32);
DEFINE_PRIM(_VOID, ndarray_fill_i64, _QD_CONTEXT _QD_NDARRAY _I64);
DEFINE_PRIM(_I64, ndarray_read_i64, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_i64, _QD_CONTEXT _QD_NDARRAY _I32 _I64);
DEFINE_PRIM(_VOID, ndarray_fill_u8, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_I32, ndarray_read_u8, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_u8, _QD_CONTEXT _QD_NDARRAY _I32 _I32);
DEFINE_PRIM(_VOID, ndarray_fill_u16, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_I32, ndarray_read_u16, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_u16, _QD_CONTEXT _QD_NDARRAY _I32 _I32);
DEFINE_PRIM(_VOID, ndarray_fill_u32, _QD_CONTEXT _QD_NDARRAY _I64);
DEFINE_PRIM(_I64, ndarray_read_u32, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_u32, _QD_CONTEXT _QD_NDARRAY _I32 _I64);
DEFINE_PRIM(_VOID, ndarray_fill_u64, _QD_CONTEXT _QD_NDARRAY _I64);
DEFINE_PRIM(_I64, ndarray_read_u64, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_u64, _QD_CONTEXT _QD_NDARRAY _I32 _I64);
DEFINE_PRIM(_VOID, ndarray_fill_f32, _QD_CONTEXT _QD_NDARRAY _F64);
DEFINE_PRIM(_F64, ndarray_read_f32, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_f32, _QD_CONTEXT _QD_NDARRAY _I32 _F64);
DEFINE_PRIM(_VOID, ndarray_fill_f64, _QD_CONTEXT _QD_NDARRAY _F64);
DEFINE_PRIM(_F64, ndarray_read_f64, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_f64, _QD_CONTEXT _QD_NDARRAY _I32 _F64);

DEFINE_PRIM(_QD_KERNEL, kernel_compile, _QD_CONTEXT _BYTES _I32);
DEFINE_PRIM(_VOID, kernel_launch, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_close, _QD_KERNEL);
