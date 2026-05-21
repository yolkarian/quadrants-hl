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
#include "quadrants/ir/frontend_ir.h"
#include "quadrants/program/kernel.h"
#include "quadrants/ir/snode.h"
#include "quadrants/program/launch_context_builder.h"
#include "quadrants/program/ndarray.h"
#include "quadrants/program/program.h"
#include "quadrants/rhi/arch.h"
#include "quadrants/util/lang_util.h"
#include "dlpack/dlpack.h"

namespace {

using quadrants::Arch;
using quadrants::host_arch;
using quadrants::hashlink::DescriptorDType;
using quadrants::hashlink::ParameterKind;
using quadrants::lang::CompiledKernelData;
using quadrants::lang::Kernel;
using quadrants::lang::LaunchContextBuilder;
using quadrants::lang::Ndarray;
using quadrants::lang::Expr;
using quadrants::lang::FieldExpression;
using quadrants::lang::PrimitiveType;
using quadrants::lang::PrimitiveTypeID;
using quadrants::lang::Program;
using quadrants::lang::SNode;
using quadrants::lang::SNodeType;

struct QdContextState {
  explicit QdContextState(Arch arch, bool enable_profiler = false) : program(std::make_unique<Program>(arch, enable_profiler)), arch(arch) {
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

class CurrentStreamScope {
 public:
  CurrentStreamScope(Program &program, quadrants::uint64 stream_handle) : program_(program) {
    program_.stream_manager().set_current_stream(stream_handle);
  }

  ~CurrentStreamScope() noexcept {
    try {
      program_.stream_manager().set_current_stream(0);
    } catch (...) {
    }
  }

 private:
  Program &program_;
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
    case 10:
      return PrimitiveType::u1;
    case 11:
      return PrimitiveType::f16;
    default:
      throw std::runtime_error("Unsupported Quadrants HashLink dtype id: " + std::to_string(dtype));
  }
}

PrimitiveTypeID primitive_id_from_bridge_id(int dtype) {
  switch (dtype) {
    case 0:
      return PrimitiveTypeID::i8;
    case 1:
      return PrimitiveTypeID::i16;
    case 2:
      return PrimitiveTypeID::i32;
    case 3:
      return PrimitiveTypeID::i64;
    case 4:
      return PrimitiveTypeID::u8;
    case 5:
      return PrimitiveTypeID::u16;
    case 6:
      return PrimitiveTypeID::u32;
    case 7:
      return PrimitiveTypeID::u64;
    case 8:
      return PrimitiveTypeID::f32;
    case 9:
      return PrimitiveTypeID::f64;
    case 10:
      return PrimitiveTypeID::u1;
    case 11:
      return PrimitiveTypeID::f16;
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
    case DescriptorDType::u1:
      return PrimitiveTypeID::u1;
    case DescriptorDType::f16:
      return PrimitiveTypeID::f16;
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
    case PrimitiveTypeID::u1:
      return "u1";
    case PrimitiveTypeID::f32:
      return "f32";
    case PrimitiveTypeID::f64:
      return "f64";
    case PrimitiveTypeID::f16:
      return "f16";
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

struct qd_kernel_metadata {
  std::vector<quadrants::hashlink::ParameterDescriptor> parameters;
  std::vector<DescriptorDType> return_dtypes;
};

struct qd_kernel {
  void (*finalize)(qd_kernel *self){nullptr};
  QdContextState *state{nullptr};
  Kernel *kernel{nullptr};
  const CompiledKernelData *compiled_kernel_data{nullptr};
  qd_kernel_metadata *metadata{nullptr};
  bool has_return{false};
  bool released{false};
};

struct qd_stream {
  void (*finalize)(qd_stream *self){nullptr};
  QdContextState *state{nullptr};
  quadrants::uint64 stream_handle{0};
  bool released{false};
};

struct qd_ndarray {
  void (*finalize)(qd_ndarray *self){nullptr};
  QdContextState *state{nullptr};
  Ndarray *array{nullptr};
  bool released{false};
};

struct qd_snode_tree {
  void (*finalize)(qd_snode_tree *self){nullptr};
  QdContextState *state{nullptr};
  std::unique_ptr<SNode> root;
  bool committed{false};
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
  delete kernel->metadata;
  kernel->metadata = nullptr;
  release_state(kernel->state);
  kernel->state = nullptr;
  kernel->released = true;
}

void release_stream_handle(qd_stream *stream) noexcept {
  if (stream == nullptr || stream->released) {
    return;
  }
  if (stream->state != nullptr && stream->state->program != nullptr) {
    try {
      stream->state->program->stream_manager().destroy_stream(stream->stream_handle);
    } catch (...) {
    }
  }
  release_state(stream->state);
  stream->state = nullptr;
  stream->stream_handle = 0;
  stream->released = true;
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

void release_snode_tree_handle(qd_snode_tree *tree) noexcept {
  if (tree == nullptr || tree->released) {
    return;
  }
  tree->root.reset();
  release_state(tree->state);
  tree->state = nullptr;
  tree->committed = false;
  tree->released = true;
}

void finalize_context(qd_context *ctx) {
  release_context_handle(ctx);
  ctx->~qd_context();
}

void finalize_kernel(qd_kernel *kernel) {
  release_kernel_handle(kernel);
  kernel->~qd_kernel();
}

void finalize_stream(qd_stream *stream) {
  release_stream_handle(stream);
  stream->~qd_stream();
}

void finalize_ndarray(qd_ndarray *array) {
  release_ndarray_handle(array);
  array->~qd_ndarray();
}

void finalize_snode_tree(qd_snode_tree *tree) {
  release_snode_tree_handle(tree);
  tree->~qd_snode_tree();
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

qd_stream &require_stream(QdContextState &state, qd_stream *stream) {
  if (stream == nullptr || stream->state == nullptr || stream->released) {
    throw std::runtime_error("Quadrants stream handle is closed");
  }
  if (stream->state != &state) {
    throw std::runtime_error("Quadrants stream belongs to a different context");
  }
  return *stream;
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
      kernel->compiled_kernel_data == nullptr || kernel->metadata == nullptr) {
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

std::vector<int> ints_from_hl_array(varray *values, const char *name) {
  if (values == nullptr) {
    throw std::runtime_error(std::string("Quadrants ") + name + " array is null");
  }
  int *items = hl_aptr(values, int);
  std::vector<int> result;
  result.reserve(values->size);
  for (int i = 0; i < values->size; ++i) {
    result.push_back(items[i]);
  }
  return result;
}

std::vector<quadrants::lang::Axis> axes_from_hl_array(varray *axes) {
  std::vector<int> axis_values = ints_from_hl_array(axes, "SNode axis");
  std::vector<quadrants::lang::Axis> result;
  result.reserve(axis_values.size());
  for (int axis : axis_values) {
    result.emplace_back(axis);
  }
  return result;
}

SNode *find_snode_in_tree(SNode *node, int snode_id) {
  if (node == nullptr) {
    return nullptr;
  }
  if (node->id == snode_id) {
    return node;
  }
  for (auto &child : node->ch) {
    if (SNode *hit = find_snode_in_tree(child.get(), snode_id)) {
      return hit;
    }
  }
  return nullptr;
}

qd_snode_tree &require_snode_tree(qd_snode_tree *tree) {
  if (tree == nullptr || tree->state == nullptr || tree->released) {
    throw std::runtime_error("Quadrants SNode tree handle is closed");
  }
  if (tree->state->program == nullptr || tree->state->closed) {
    throw std::runtime_error("Quadrants SNode tree context is closed");
  }
  return *tree;
}

SNode &require_pending_snode(qd_snode_tree &tree, int snode_id) {
  if (tree.committed || tree.root == nullptr) {
    throw std::runtime_error("Quadrants SNode tree is already committed");
  }
  SNode *snode = find_snode_in_tree(tree.root.get(), snode_id);
  if (snode == nullptr) {
    throw std::runtime_error("Quadrants SNode id is not part of the pending tree");
  }
  return *snode;
}

SNode &require_committed_place_snode(QdContextState &state, int snode_id) {
  SNode *snode = state.program->get_snode_by_id(snode_id);
  if (snode == nullptr) {
    throw std::runtime_error("Quadrants SNode id is not part of this context");
  }
  if (!snode->is_place()) {
    throw std::runtime_error("Quadrants SNode host access requires a placed field");
  }
  return *snode;
}

SNodeType snode_type_from_bridge_id(int type) {
  switch (type) {
    case 1:
      return SNodeType::dense;
    case 2:
      return SNodeType::dynamic;
    case 3:
      return SNodeType::pointer;
    case 4:
      return SNodeType::bitmasked;
    case 5:
      return SNodeType::hash;
    default:
      throw std::runtime_error("Unsupported Quadrants SNode type id: " + std::to_string(type));
  }
}

SNode &create_child_snode(SNode &parent, int type, varray *axes, varray *sizes, int chunk_size) {
  std::vector<quadrants::lang::Axis> axis_values = axes_from_hl_array(axes);
  std::vector<int> size_values = ints_from_hl_array(sizes, "SNode size");
  SNodeType snode_type = snode_type_from_bridge_id(type);
  if (snode_type == SNodeType::dynamic) {
    if (axis_values.size() != 1 || size_values.size() != 1) {
      throw std::runtime_error("Quadrants dynamic SNode requires exactly one axis and one size");
    }
    if (chunk_size <= 0) {
      throw std::runtime_error("Quadrants dynamic SNode chunk size must be positive");
    }
    return parent.dynamic(axis_values[0], size_values[0], chunk_size);
  }
  return parent.create_node(std::move(axis_values), std::move(size_values), snode_type);
}

std::vector<int> checked_snode_indices(SNode &snode, varray *indices) {
  std::vector<int> result = ints_from_hl_array(indices, "SNode index");
  if (result.size() != static_cast<std::size_t>(snode.num_active_indices)) {
    throw std::runtime_error("Quadrants SNode index rank mismatch");
  }
  return result;
}

int64 read_snode_int(QdContextState &state, int snode_id, varray *indices) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  return snode.read_int(checked_snode_indices(snode, indices));
}

quadrants::uint64 read_snode_uint(QdContextState &state, int snode_id, varray *indices) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  return snode.read_uint(checked_snode_indices(snode, indices));
}

double read_snode_float(QdContextState &state, int snode_id, varray *indices) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  return snode.read_float(checked_snode_indices(snode, indices));
}

void write_snode_int(QdContextState &state, int snode_id, varray *indices, int64 value) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  snode.write_int(checked_snode_indices(snode, indices), value);
}

void write_snode_uint(QdContextState &state, int snode_id, varray *indices, quadrants::uint64 value) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  snode.write_uint(checked_snode_indices(snode, indices), value);
}

void write_snode_float(QdContextState &state, int snode_id, varray *indices, double value) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  snode.write_float(checked_snode_indices(snode, indices), value);
}

struct QdDlpackManager {
  QdContextState *state{nullptr};
  std::int64_t *shape{nullptr};
  std::int64_t *strides{nullptr};
};

void dlpack_deleter(DLManagedTensor *self) {
  if (self == nullptr) {
    return;
  }
  auto *manager = static_cast<QdDlpackManager *>(self->manager_ctx);
  if (manager != nullptr) {
    delete[] manager->shape;
    delete[] manager->strides;
    release_state(manager->state);
    delete manager;
  }
  delete self;
}

DLDeviceType dl_device_type_from_arch(Arch arch) {
  if (quadrants::arch_is_cpu(arch)) {
    return kDLCPU;
  }
  if (quadrants::arch_is_cuda(arch)) {
    return kDLCUDA;
  }
  if (quadrants::arch_is_amdgpu(arch)) {
    return kDLROCM;
  }
  if (quadrants::arch_is_metal(arch)) {
    return kDLMetal;
  }
  if (arch == Arch::vulkan) {
    return kDLVulkan;
  }
  throw std::runtime_error("Unsupported Quadrants DLPack device arch");
}

DLDataType dl_dtype_from_ndarray(const Ndarray &array) {
  const auto dtype = array.get_element_data_type();
  if (dtype->is_primitive(PrimitiveTypeID::i8)) {
    return DLDataType{static_cast<std::uint8_t>(kDLInt), 8, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::i16)) {
    return DLDataType{static_cast<std::uint8_t>(kDLInt), 16, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::i32)) {
    return DLDataType{static_cast<std::uint8_t>(kDLInt), 32, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::i64)) {
    return DLDataType{static_cast<std::uint8_t>(kDLInt), 64, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::u8)) {
    return DLDataType{static_cast<std::uint8_t>(kDLUInt), 8, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::u16)) {
    return DLDataType{static_cast<std::uint8_t>(kDLUInt), 16, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::u32)) {
    return DLDataType{static_cast<std::uint8_t>(kDLUInt), 32, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::u64)) {
    return DLDataType{static_cast<std::uint8_t>(kDLUInt), 64, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::u1)) {
    return DLDataType{static_cast<std::uint8_t>(kDLBool), 8, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::f16)) {
    return DLDataType{static_cast<std::uint8_t>(kDLFloat), 16, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::f32)) {
    return DLDataType{static_cast<std::uint8_t>(kDLFloat), 32, 1};
  }
  if (dtype->is_primitive(PrimitiveTypeID::f64)) {
    return DLDataType{static_cast<std::uint8_t>(kDLFloat), 64, 1};
  }
  throw std::runtime_error("Quadrants DLPack export only supports primitive ndarrays");
}

DLManagedTensor *checked_dlpack_handle(int64 value) {
  if (value == 0) {
    throw std::runtime_error("Quadrants DLPack handle is null");
  }
  return reinterpret_cast<DLManagedTensor *>(static_cast<intptr_t>(value));
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

void read_ndarray_bytes(QdContextState &state,
                        qd_ndarray *arr,
                        PrimitiveTypeID dtype,
                        int flat_start,
                        int count,
                        vbyte *out,
                        int out_byte_offset) {
  Ndarray &array = require_typed_ndarray(state, arr, dtype);
  if (out == nullptr) {
    throw std::runtime_error("Quadrants byte read output buffer is null");
  }
  if (flat_start < 0) {
    throw std::runtime_error("Quadrants byte read flat start is negative");
  }
  if (count < 0) {
    throw std::runtime_error("Quadrants byte read count is negative");
  }
  if (out_byte_offset < 0) {
    throw std::runtime_error("Quadrants byte read output byte offset is negative");
  }

  const std::size_t total = array.get_nelement();
  const std::size_t start = static_cast<std::size_t>(flat_start);
  const std::size_t element_count = static_cast<std::size_t>(count);
  if (start > total || element_count > total - start) {
    throw std::runtime_error("Quadrants byte read range is out of bounds");
  }

  state.program->check_adstack_overflow_and_assert();
  state.program->synchronize();

  const std::size_t element_size = array.get_element_size();
  if (element_count > std::numeric_limits<std::size_t>::max() / element_size) {
    throw std::runtime_error("Quadrants byte read size overflows size_t");
  }
  const std::size_t byte_count = element_count * element_size;
  if (byte_count == 0) {
    return;
  }

  quadrants::lang::Device::AllocParams alloc_params;
  alloc_params.host_write = false;
  alloc_params.host_read = true;
  alloc_params.size = byte_count;
  alloc_params.usage = quadrants::lang::AllocUsage::Storage;
  auto [staging_buf, res] = array.ndarray_alloc_.device->allocate_memory_unique(alloc_params);
  QD_ASSERT(res == quadrants::lang::RhiResult::success);
  staging_buf->device->memcpy_internal(staging_buf->get_ptr(), array.ndarray_alloc_.get_ptr(start * element_size),
                                       byte_count);

  void *mapped{nullptr};
  QD_ASSERT(staging_buf->device->map(*staging_buf, &mapped) == quadrants::lang::RhiResult::success);
  QD_ASSERT(mapped != nullptr);
  std::memcpy(reinterpret_cast<std::uint8_t *>(out) + static_cast<std::size_t>(out_byte_offset), mapped, byte_count);
  staging_buf->device->unmap(*staging_buf);
}

void write_ndarray_bytes(QdContextState &state,
                         qd_ndarray *arr,
                         PrimitiveTypeID dtype,
                         int flat_start,
                         int count,
                         vbyte *input,
                         int input_byte_offset) {
  Ndarray &array = require_typed_ndarray(state, arr, dtype);
  if (input == nullptr) {
    throw std::runtime_error("Quadrants byte write input buffer is null");
  }
  if (flat_start < 0) {
    throw std::runtime_error("Quadrants byte write flat start is negative");
  }
  if (count < 0) {
    throw std::runtime_error("Quadrants byte write count is negative");
  }
  if (input_byte_offset < 0) {
    throw std::runtime_error("Quadrants byte write input byte offset is negative");
  }

  const std::size_t total = array.get_nelement();
  const std::size_t start = static_cast<std::size_t>(flat_start);
  const std::size_t element_count = static_cast<std::size_t>(count);
  if (start > total || element_count > total - start) {
    throw std::runtime_error("Quadrants byte write range is out of bounds");
  }

  state.program->check_adstack_overflow_and_assert();
  state.program->synchronize();

  const std::size_t element_size = array.get_element_size();
  if (element_count > std::numeric_limits<std::size_t>::max() / element_size) {
    throw std::runtime_error("Quadrants byte write size overflows size_t");
  }
  const std::size_t byte_count = element_count * element_size;
  if (byte_count == 0) {
    return;
  }

  quadrants::lang::Device::AllocParams alloc_params;
  alloc_params.host_write = true;
  alloc_params.host_read = false;
  alloc_params.size = byte_count;
  alloc_params.usage = quadrants::lang::AllocUsage::Storage;
  auto [staging_buf, res] = array.ndarray_alloc_.device->allocate_memory_unique(alloc_params);
  QD_ASSERT(res == quadrants::lang::RhiResult::success);

  void *mapped{nullptr};
  QD_ASSERT(staging_buf->device->map(*staging_buf, &mapped) == quadrants::lang::RhiResult::success);
  QD_ASSERT(mapped != nullptr);
  std::memcpy(mapped, reinterpret_cast<const std::uint8_t *>(input) + static_cast<std::size_t>(input_byte_offset),
              byte_count);
  staging_buf->device->unmap(*staging_buf);
  staging_buf->device->memcpy_internal(array.ndarray_alloc_.get_ptr(start * element_size), staging_buf->get_ptr(),
                                       byte_count);
}


quadrants::lang::KernelProfilerBase &require_profiler(QdContextState &state) {
  auto *profiler = state.program->get_profiler();
  if (profiler == nullptr) {
    throw std::runtime_error("Quadrants profiler is not enabled for this context");
  }
  return *profiler;
}
void set_scalar_arg(LaunchContextBuilder &launch_context, int arg_id, DescriptorDType dtype, vdynamic *value) {
  switch (dtype) {
    case DescriptorDType::i8:
    case DescriptorDType::i16:
    case DescriptorDType::i32:
      launch_context.set_arg_int(arg_id, hl_dyn_casti(&value, &hlt_dyn, &hlt_i32));
      return;
    case DescriptorDType::u1:
      launch_context.set_arg_uint(arg_id, static_cast<uint64>(hl_dyn_casti(&value, &hlt_dyn, &hlt_bool) != 0));
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
    case DescriptorDType::f16:
      launch_context.set_arg_float(arg_id, hl_dyn_castd(&value, &hlt_dyn));
      return;
  }
  throw std::runtime_error("Unsupported Quadrants HashLink scalar dtype");
}

void set_kernel_launch_args(QdContextState &state, qd_kernel *kernel, varray *args, LaunchContextBuilder &launch_context) {
  if (args == nullptr) {
    throw std::runtime_error("Quadrants kernel argument array is null");
  }
  const auto &parameters = kernel->metadata->parameters;
  if (args->size != static_cast<int>(parameters.size())) {
    throw std::runtime_error("Quadrants kernel argument count mismatch");
  }

  vdynamic **values = hl_aptr(args, vdynamic *);
  for (std::size_t i = 0; i < parameters.size(); ++i) {
    const auto &param = parameters[i];
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
}

void configure_graph_do_while(qd_kernel *kernel, int control_arg_id, LaunchContextBuilder &launch_context) {
  const auto &parameters = kernel->metadata->parameters;
  if (control_arg_id < 0 || control_arg_id >= static_cast<int>(parameters.size())) {
    throw std::runtime_error("Quadrants graph_do_while control argument index is out of range");
  }
  const auto &param = parameters[static_cast<std::size_t>(control_arg_id)];
  if (param.kind != ParameterKind::ndarray || param.dtype != DescriptorDType::i32) {
    throw std::runtime_error("Quadrants graph_do_while control argument must be an I32 Tensor");
  }
  launch_context.use_graph = true;
  launch_context.graph_do_while_arg_id = control_arg_id;
}

vdynamic *make_dynamic_return(LaunchContextBuilder &launch_context, DescriptorDType dtype, int ret_id) {
  const auto ret = launch_context.fetch_ret({ret_id});
  switch (dtype) {
    case DescriptorDType::u1:
      return hl_alloc_dynbool(ret.val_uint() != 0);
    case DescriptorDType::i8:
    case DescriptorDType::i16:
    case DescriptorDType::i32: {
      auto *out = hl_alloc_dynamic(&hlt_i32);
      out->v.i = static_cast<int>(ret.val_int());
      return out;
    }
    case DescriptorDType::u8:
    case DescriptorDType::u16:
    case DescriptorDType::u32:
    case DescriptorDType::u64: {
      auto *out = hl_alloc_dynamic(&hlt_i64);
      const auto value = ret.val_uint();
      std::memcpy(&out->v.i64, &value, sizeof(value));
      return out;
    }
    case DescriptorDType::i64: {
      auto *out = hl_alloc_dynamic(&hlt_i64);
      out->v.i64 = static_cast<quadrants::int64>(ret.val_int());
      return out;
    }
    case DescriptorDType::f16:
    case DescriptorDType::f32:
    case DescriptorDType::f64: {
      auto *out = hl_alloc_dynamic(&hlt_f64);
      out->v.d = ret.val_float();
      return out;
    }
  }
  throw std::runtime_error("Unsupported Quadrants HashLink return dtype");
}

varray *make_dynamic_returns(LaunchContextBuilder &launch_context, const std::vector<DescriptorDType> &dtypes) {
  auto *out = hl_alloc_array(&hlt_dyn, static_cast<int>(dtypes.size()));
  auto **values = hl_aptr(out, vdynamic *);
  for (std::size_t i = 0; i < dtypes.size(); ++i) {
    values[i] = make_dynamic_return(launch_context, dtypes[i], static_cast<int>(i));
  }
  return out;
}

}  // namespace

HL_PRIM void HL_NAME(runtime_set_lib_dir)(vbyte *path) {
  guard([&]() {
    if (path == nullptr) {
      throw std::runtime_error("Quadrants runtime library directory is null");
    }
    quadrants::lang::compiled_lib_dir = std::string(reinterpret_cast<const char *>(path));
  });
}

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

HL_PRIM qd_context *HL_NAME(context_create_configured)(int arch, int enable_profiler) {
  return guard([&]() -> qd_context * {
    BlockingSection blocking;
    auto *state = new QdContextState(arch_from_bridge_id(arch), enable_profiler != 0);
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

HL_PRIM qd_stream *HL_NAME(stream_create)(qd_context *ctx) {
  return guard([&]() -> qd_stream * {
    QdContextState &state = require_context(ctx);
    BlockingSection blocking;
    auto *handle = static_cast<qd_stream *>(hl_gc_alloc_finalizer(sizeof(qd_stream)));
    new (handle) qd_stream();
    handle->finalize = finalize_stream;
    handle->state = &state;
    handle->stream_handle = state.program->stream_manager().create_stream();
    retain_state(&state);
    return handle;
  });
}

HL_PRIM void HL_NAME(stream_sync)(qd_context *ctx, qd_stream *stream) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_stream &stream_ref = require_stream(state, stream);
    BlockingSection blocking;
    state.program->stream_manager().synchronize_stream(stream_ref.stream_handle);
  });
}

HL_PRIM void HL_NAME(stream_close)(qd_stream *stream) {
  guard([&]() { release_stream_handle(stream); });
}

HL_PRIM void HL_NAME(context_set_offline_cache)(qd_context *ctx, int enabled, vbyte *path) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    auto &config = state.program->mutable_compile_config();
    config.offline_cache = enabled != 0;
    if (path != nullptr) {
      config.offline_cache_file_path = std::string(reinterpret_cast<const char *>(path));
    }
  });
}

HL_PRIM void HL_NAME(context_set_adstack_config)(qd_context *ctx,
                                                int experimental_enabled,
                                                int stack_size,
                                                int sparse_threshold_bytes) {
  guard([&]() {
    if (stack_size < 0) {
      throw std::runtime_error("Quadrants adstack size must be non-negative");
    }
    if (sparse_threshold_bytes < 0) {
      throw std::runtime_error("Quadrants adstack sparse threshold must be non-negative");
    }
    QdContextState &state = require_context(ctx);
    auto &config = state.program->mutable_compile_config();
    config.ad_stack_experimental_enabled = experimental_enabled != 0;
    config.ad_stack_size = stack_size;
    config.ad_stack_sparse_threshold_bytes = static_cast<std::size_t>(sparse_threshold_bytes);
  });
}


HL_PRIM void HL_NAME(context_set_debug_dump)(qd_context *ctx,
                                            vbyte *path,
                                            int print_ir,
                                            int print_preprocessed_ir,
                                            int print_ir_debug_info) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    auto &config = state.program->mutable_compile_config();
    if (path != nullptr) {
      config.debug_dump_path = std::string(reinterpret_cast<const char *>(path));
    }
    config.print_ir = print_ir != 0;
    config.print_preprocessed_ir = print_preprocessed_ir != 0;
    config.print_ir_dbg_info = print_ir_debug_info != 0;
  });
}
HL_PRIM void HL_NAME(profiler_start)(qd_context *ctx, vbyte *kernel_name) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    require_profiler(state);
    state.program->profiler_start(
        kernel_name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(kernel_name)));
  });
}

HL_PRIM void HL_NAME(profiler_stop)(qd_context *ctx) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    require_profiler(state);
    state.program->profiler_stop();
  });
}

HL_PRIM void HL_NAME(profiler_clear)(qd_context *ctx) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    require_profiler(state).clear();
  });
}

HL_PRIM double HL_NAME(profiler_total_time)(qd_context *ctx) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    return require_profiler(state).get_total_time();
  });
}

HL_PRIM void HL_NAME(context_set_random_seed)(qd_context *ctx, int seed) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    state.program->mutable_compile_config().random_seed = seed;
  });
}


HL_PRIM void HL_NAME(context_set_cpu_max_num_threads)(qd_context *ctx, int thread_count) {
  guard([&]() {
    if (thread_count <= 0) {
      throw std::runtime_error("Quadrants CPU max thread count must be positive");
    }
    QdContextState &state = require_context(ctx);
    state.program->mutable_compile_config().cpu_max_num_threads = thread_count;
  });
}

HL_PRIM void HL_NAME(context_set_fast_math)(qd_context *ctx, int enabled) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    state.program->mutable_compile_config().fast_math = enabled != 0;
  });
}

HL_PRIM void HL_NAME(context_set_bounds_check)(qd_context *ctx, int enabled) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    state.program->mutable_compile_config().check_out_of_bound = enabled != 0;
  });
}
HL_PRIM int HL_NAME(profiler_query_count)(qd_context *ctx, vbyte *kernel_name) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    require_profiler(state);
    auto result = state.program->query_kernel_profile_info(
        kernel_name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(kernel_name)));
    return result.counter;
  });
}

HL_PRIM double HL_NAME(profiler_query_avg)(qd_context *ctx, vbyte *kernel_name) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    require_profiler(state);
    auto result = state.program->query_kernel_profile_info(
        kernel_name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(kernel_name)));
    return result.avg;
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

HL_PRIM void HL_NAME(ndarray_close)(qd_ndarray *arr) {
  guard([&]() { release_ndarray_handle(arr); });
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

HL_PRIM void HL_NAME(ndarray_fill_u1)(qd_context *ctx, qd_ndarray *arr, int value) {
  guard([&]() { fill_ndarray_int(require_context(ctx), arr, PrimitiveTypeID::u1, value != 0 ? 1 : 0); });
}

HL_PRIM int HL_NAME(ndarray_read_u1)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u1);
    return array.read_uint(flat_to_indices(array, flat_index)) != 0 ? 1 : 0;
  });
}

HL_PRIM void HL_NAME(ndarray_write_u1)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::u1);
    array.write_int(flat_to_indices(array, flat_index), value != 0 ? 1 : 0);
  });
}


HL_PRIM void HL_NAME(ndarray_fill_f32)(qd_context *ctx, qd_ndarray *arr, double value) {
  guard([&]() { fill_ndarray_float(require_context(ctx), arr, PrimitiveTypeID::f32, value); });
}

HL_PRIM void HL_NAME(ndarray_fill_f16)(qd_context *ctx, qd_ndarray *arr, double value) {
  guard([&]() { fill_ndarray_float(require_context(ctx), arr, PrimitiveTypeID::f16, value); });
}


HL_PRIM void HL_NAME(ndarray_read_bytes)(qd_context *ctx,
                                         qd_ndarray *arr,
                                         int dtype,
                                         int flat_start,
                                         int count,
                                         vbyte *out,
                                         int out_byte_offset) {
  guard([&]() {
    read_ndarray_bytes(require_context(ctx), arr, primitive_id_from_bridge_id(dtype), flat_start, count, out,
                       out_byte_offset);
  });
}

HL_PRIM void HL_NAME(ndarray_write_bytes)(qd_context *ctx,
                                          qd_ndarray *arr,
                                          int dtype,
                                          int flat_start,
                                          int count,
                                          vbyte *input,
                                          int input_byte_offset) {
  guard([&]() {
    write_ndarray_bytes(require_context(ctx), arr, primitive_id_from_bridge_id(dtype), flat_start, count, input,
                        input_byte_offset);
  });
}

HL_PRIM double HL_NAME(ndarray_read_f32)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f32);
    return array.read_float(flat_to_indices(array, flat_index));
  });
}

HL_PRIM void HL_NAME(ndarray_read_f32_bytes)(qd_context *ctx,
                                             qd_ndarray *arr,
                                             int flat_start,
                                             int count,
                                             vbyte *out,
                                             int out_byte_offset) {
  guard([&]() {
    read_ndarray_bytes(require_context(ctx), arr, PrimitiveTypeID::f32, flat_start, count, out, out_byte_offset);
  });
}

HL_PRIM void HL_NAME(ndarray_write_f32)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f32);
    array.write_float(flat_to_indices(array, flat_index), value);
  });
}

HL_PRIM double HL_NAME(ndarray_read_f16)(qd_context *ctx, qd_ndarray *arr, int flat_index) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f16);
    return array.read_float(flat_to_indices(array, flat_index));
  });
}

HL_PRIM void HL_NAME(ndarray_write_f16)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_typed_ndarray(state, arr, PrimitiveTypeID::f16);
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

HL_PRIM int HL_NAME(ndarray_supports_zero_copy)(qd_context *ctx) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return quadrants::arch_uses_llvm(state.arch) ? 1 : 0;
  });
}

HL_PRIM int64 HL_NAME(ndarray_export_device_pointer)(qd_context *ctx, qd_ndarray *arr) {
  return guard([&]() -> int64 {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_ndarray(state, arr);
    if (!quadrants::arch_uses_llvm(state.arch)) {
      throw std::runtime_error("Quadrants device pointer export requires an LLVM-backed context");
    }
    state.program->synchronize();
    const intptr_t ptr = state.program->get_ndarray_data_ptr_as_int(&array);
    if (ptr == 0) {
      throw std::runtime_error("Quadrants device pointer export returned a null pointer");
    }
    return static_cast<int64>(ptr);
  });
}

HL_PRIM int64 HL_NAME(ndarray_export_dlpack)(qd_context *ctx, qd_ndarray *arr) {
  return guard([&]() -> int64 {
    QdContextState &state = require_context(ctx);
    Ndarray &array = require_ndarray(state, arr);
    if (!quadrants::arch_uses_llvm(state.arch)) {
      throw std::runtime_error("Quadrants DLPack export requires an LLVM-backed context");
    }
    state.program->synchronize();
    const intptr_t ptr = state.program->get_ndarray_data_ptr_as_int(&array);
    if (ptr == 0) {
      throw std::runtime_error("Quadrants DLPack export returned a null data pointer");
    }
    const int ndim = static_cast<int>(array.shape.size());
    auto *managed = new DLManagedTensor{};
    auto *manager = new QdDlpackManager{};
    manager->state = &state;
    manager->shape = new std::int64_t[ndim];
    manager->strides = new std::int64_t[ndim];
    for (int i = 0; i < ndim; ++i) {
      manager->shape[i] = array.shape[static_cast<std::size_t>(i)];
    }
    std::int64_t stride = 1;
    for (int i = ndim; i > 0; --i) {
      const int axis = i - 1;
      manager->strides[axis] = stride;
      stride *= manager->shape[axis];
    }
    managed->dl_tensor.data = reinterpret_cast<void *>(ptr);
    managed->dl_tensor.device = DLDevice{dl_device_type_from_arch(state.arch), 0};
    managed->dl_tensor.ndim = ndim;
    managed->dl_tensor.dtype = dl_dtype_from_ndarray(array);
    managed->dl_tensor.shape = manager->shape;
    managed->dl_tensor.strides = manager->strides;
    managed->dl_tensor.byte_offset = 0;
    managed->manager_ctx = manager;
    managed->deleter = dlpack_deleter;
    retain_state(&state);
    return static_cast<int64>(reinterpret_cast<intptr_t>(managed));
  });
}

HL_PRIM void HL_NAME(dlpack_release)(int64 handle) {
  guard([&]() {
    DLManagedTensor *managed = checked_dlpack_handle(handle);
    if (managed->deleter == nullptr) {
      throw std::runtime_error("Quadrants DLPack handle has no deleter");
    }
    managed->deleter(managed);
  });
}

HL_PRIM int HL_NAME(dlpack_device_type)(int64 handle) {
  return guard([&]() -> int { return static_cast<int>(checked_dlpack_handle(handle)->dl_tensor.device.device_type); });
}

HL_PRIM int HL_NAME(dlpack_device_id)(int64 handle) {
  return guard([&]() -> int { return checked_dlpack_handle(handle)->dl_tensor.device.device_id; });
}

HL_PRIM int HL_NAME(dlpack_dtype_code)(int64 handle) {
  return guard([&]() -> int { return checked_dlpack_handle(handle)->dl_tensor.dtype.code; });
}

HL_PRIM int HL_NAME(dlpack_dtype_bits)(int64 handle) {
  return guard([&]() -> int { return checked_dlpack_handle(handle)->dl_tensor.dtype.bits; });
}

HL_PRIM int HL_NAME(dlpack_dtype_lanes)(int64 handle) {
  return guard([&]() -> int { return checked_dlpack_handle(handle)->dl_tensor.dtype.lanes; });
}

HL_PRIM int HL_NAME(dlpack_ndim)(int64 handle) {
  return guard([&]() -> int { return checked_dlpack_handle(handle)->dl_tensor.ndim; });
}

HL_PRIM int64 HL_NAME(dlpack_shape)(int64 handle, int axis) {
  return guard([&]() -> int64 {
    DLManagedTensor *managed = checked_dlpack_handle(handle);
    if (axis < 0 || axis >= managed->dl_tensor.ndim) {
      throw std::runtime_error("Quadrants DLPack shape axis is out of range");
    }
    return static_cast<int64>(managed->dl_tensor.shape[axis]);
  });
}

HL_PRIM int64 HL_NAME(dlpack_stride)(int64 handle, int axis) {
  return guard([&]() -> int64 {
    DLManagedTensor *managed = checked_dlpack_handle(handle);
    if (axis < 0 || axis >= managed->dl_tensor.ndim) {
      throw std::runtime_error("Quadrants DLPack stride axis is out of range");
    }
    return static_cast<int64>(managed->dl_tensor.strides[axis]);
  });
}

HL_PRIM int64 HL_NAME(dlpack_data_pointer)(int64 handle) {
  return guard([&]() -> int64 {
    return static_cast<int64>(reinterpret_cast<intptr_t>(checked_dlpack_handle(handle)->dl_tensor.data));
  });
}

HL_PRIM qd_snode_tree *HL_NAME(snode_tree_create)(qd_context *ctx) {
  return guard([&]() -> qd_snode_tree * {
    QdContextState &state = require_context(ctx);
    auto *handle = static_cast<qd_snode_tree *>(hl_gc_alloc_finalizer(sizeof(qd_snode_tree)));
    new (handle) qd_snode_tree();
    handle->finalize = finalize_snode_tree;
    handle->state = &state;
    handle->root = std::make_unique<SNode>(0, SNodeType::root, state.program->get_snode_to_fields(),
                                           &state.program->get_snode_rw_accessors_bank());
    retain_state(&state);
    return handle;
  });
}

HL_PRIM int HL_NAME(snode_tree_root_id)(qd_snode_tree *tree) {
  return guard([&]() -> int {
    qd_snode_tree &tree_ref = require_snode_tree(tree);
    if (tree_ref.root == nullptr) {
      throw std::runtime_error("Quadrants SNode tree has already been committed");
    }
    return tree_ref.root->id;
  });
}

HL_PRIM int HL_NAME(snode_tree_child)(qd_snode_tree *tree,
                                      int parent_snode_id,
                                      int snode_type,
                                      varray *axes,
                                      varray *sizes,
                                      int chunk_size) {
  return guard([&]() -> int {
    qd_snode_tree &tree_ref = require_snode_tree(tree);
    SNode &parent = require_pending_snode(tree_ref, parent_snode_id);
    return create_child_snode(parent, snode_type, axes, sizes, chunk_size).id;
  });
}

HL_PRIM int HL_NAME(snode_tree_place)(qd_snode_tree *tree, int parent_snode_id, int dtype, vbyte *name) {
  return guard([&]() -> int {
    qd_snode_tree &tree_ref = require_snode_tree(tree);
    SNode &parent = require_pending_snode(tree_ref, parent_snode_id);
    QdContextState &state = *tree_ref.state;
    const std::string field_name = name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(name));
    Expr field = Expr::make<FieldExpression>(dtype_from_bridge_id(dtype), state.program->get_next_global_id(field_name));
    parent.place(field, {}, -1);
    return field.snode()->id;
  });
}

HL_PRIM int HL_NAME(snode_tree_commit)(qd_context *ctx, qd_snode_tree *tree) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    qd_snode_tree &tree_ref = require_snode_tree(tree);
    if (tree_ref.state != &state) {
      throw std::runtime_error("Quadrants SNode tree belongs to a different context");
    }
    if (tree_ref.committed || tree_ref.root == nullptr) {
      throw std::runtime_error("Quadrants SNode tree has already been committed");
    }
    auto *materialized = state.program->add_snode_tree(std::move(tree_ref.root), false);
    tree_ref.committed = true;
    return materialized->id();
  });
}

HL_PRIM void HL_NAME(snode_tree_close)(qd_snode_tree *tree) {
  guard([&]() { release_snode_tree_handle(tree); });
}

HL_PRIM int HL_NAME(snode_read_i8)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int { return static_cast<int>(read_snode_int(require_context(ctx), snode_id, indices)); });
}

HL_PRIM void HL_NAME(snode_write_i8)(qd_context *ctx, int snode_id, varray *indices, int value) {
  guard([&]() { write_snode_int(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM int HL_NAME(snode_read_i16)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int { return static_cast<int>(read_snode_int(require_context(ctx), snode_id, indices)); });
}

HL_PRIM void HL_NAME(snode_write_i16)(qd_context *ctx, int snode_id, varray *indices, int value) {
  guard([&]() { write_snode_int(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM int HL_NAME(snode_read_i32)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int { return static_cast<int>(read_snode_int(require_context(ctx), snode_id, indices)); });
}

HL_PRIM void HL_NAME(snode_write_i32)(qd_context *ctx, int snode_id, varray *indices, int value) {
  guard([&]() { write_snode_int(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM int64 HL_NAME(snode_read_i64)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int64 { return static_cast<int64>(read_snode_int(require_context(ctx), snode_id, indices)); });
}

HL_PRIM void HL_NAME(snode_write_i64)(qd_context *ctx, int snode_id, varray *indices, int64 value) {
  guard([&]() { write_snode_int(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM int HL_NAME(snode_read_u8)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int { return static_cast<int>(read_snode_uint(require_context(ctx), snode_id, indices)); });
}

HL_PRIM void HL_NAME(snode_write_u8)(qd_context *ctx, int snode_id, varray *indices, int value) {
  guard([&]() { write_snode_uint(require_context(ctx), snode_id, indices, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM int HL_NAME(snode_read_u16)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int { return static_cast<int>(read_snode_uint(require_context(ctx), snode_id, indices)); });
}

HL_PRIM void HL_NAME(snode_write_u16)(qd_context *ctx, int snode_id, varray *indices, int value) {
  guard([&]() { write_snode_uint(require_context(ctx), snode_id, indices, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM int64 HL_NAME(snode_read_u32)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int64 {
    return static_cast<int64>(read_snode_uint(require_context(ctx), snode_id, indices));
  });
}

HL_PRIM void HL_NAME(snode_write_u32)(qd_context *ctx, int snode_id, varray *indices, int64 value) {
  guard([&]() { write_snode_uint(require_context(ctx), snode_id, indices, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM int64 HL_NAME(snode_read_u64)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int64 {
    return static_cast<int64>(read_snode_uint(require_context(ctx), snode_id, indices));
  });
}

HL_PRIM void HL_NAME(snode_write_u64)(qd_context *ctx, int snode_id, varray *indices, int64 value) {
  guard([&]() { write_snode_uint(require_context(ctx), snode_id, indices, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM int HL_NAME(snode_read_u1)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> int { return read_snode_uint(require_context(ctx), snode_id, indices) != 0 ? 1 : 0; });
}

HL_PRIM void HL_NAME(snode_write_u1)(qd_context *ctx, int snode_id, varray *indices, int value) {
  guard([&]() { write_snode_uint(require_context(ctx), snode_id, indices, value != 0 ? 1 : 0); });
}

HL_PRIM double HL_NAME(snode_read_f32)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> double { return read_snode_float(require_context(ctx), snode_id, indices); });
}

HL_PRIM void HL_NAME(snode_write_f32)(qd_context *ctx, int snode_id, varray *indices, double value) {
  guard([&]() { write_snode_float(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM double HL_NAME(snode_read_f16)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> double { return read_snode_float(require_context(ctx), snode_id, indices); });
}

HL_PRIM void HL_NAME(snode_write_f16)(qd_context *ctx, int snode_id, varray *indices, double value) {
  guard([&]() { write_snode_float(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM double HL_NAME(snode_read_f64)(qd_context *ctx, int snode_id, varray *indices) {
  return guard([&]() -> double { return read_snode_float(require_context(ctx), snode_id, indices); });
}

HL_PRIM void HL_NAME(snode_write_f64)(qd_context *ctx, int snode_id, varray *indices, double value) {
  guard([&]() { write_snode_float(require_context(ctx), snode_id, indices, value); });
}

HL_PRIM qd_kernel *HL_NAME(kernel_compile)(qd_context *ctx, vbyte *descriptor_bytes, int descriptor_length, int autodiff_mode) {
  return guard([&]() -> qd_kernel * {
    QdContextState &state = require_context(ctx);
    if (descriptor_length < 0) {
      throw std::runtime_error("HashLink kernel descriptor length is negative");
    }
    BlockingSection blocking;
    quadrants::hashlink::KernelDescriptor descriptor = quadrants::hashlink::decode_descriptor(
        reinterpret_cast<const std::uint8_t *>(descriptor_bytes), static_cast<std::size_t>(descriptor_length));
    quadrants::hashlink::KernelBuildResult result = quadrants::hashlink::build_kernel_from_descriptor(
        *state.program, descriptor, quadrants::hashlink::autodiff_mode_from_bridge_id(autodiff_mode));

    auto metadata = std::make_unique<qd_kernel_metadata>();
    metadata->parameters = descriptor.parameters;
    metadata->return_dtypes = descriptor.return_dtypes;

    auto *handle = static_cast<qd_kernel *>(hl_gc_alloc_finalizer(sizeof(qd_kernel)));
    new (handle) qd_kernel();
    handle->finalize = finalize_kernel;
    handle->state = &state;
    handle->kernel = result.kernel;
    handle->compiled_kernel_data = result.compiled_kernel_data;
    handle->metadata = metadata.release();
    handle->has_return = descriptor.has_return;
    retain_state(&state);
    return handle;
  });
}

HL_PRIM void HL_NAME(kernel_launch)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    set_kernel_launch_args(state, kernel, args, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_launch_graph)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    launch_context.use_graph = true;
    set_kernel_launch_args(state, kernel, args, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_launch_graph_do_while)(qd_context *ctx, qd_kernel *kernel, int control_arg_id, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    configure_graph_do_while(kernel, control_arg_id, launch_context);
    set_kernel_launch_args(state, kernel, args, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_launch_on)(qd_context *ctx, qd_kernel *kernel, qd_stream *stream, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    qd_stream &stream_ref = require_stream(state, stream);
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    set_kernel_launch_args(state, kernel, args, launch_context);

    BlockingSection blocking;
    CurrentStreamScope current_stream(*state.program, stream_ref.stream_handle);
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
  });
}

HL_PRIM vdynamic *HL_NAME(kernel_launch_ret)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  return guard([&]() -> vdynamic * {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    if (!kernel->has_return) {
      throw std::runtime_error("Quadrants kernel has no return value");
    }
    const auto &return_dtypes = kernel->metadata->return_dtypes;
    if (return_dtypes.size() != 1) {
      throw std::runtime_error("Quadrants kernel returns multiple values; use launchRets");
    }
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    set_kernel_launch_args(state, kernel, args, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
    state.program->synchronize_and_assert();
    return make_dynamic_return(launch_context, return_dtypes.front(), 0);
  });
}

HL_PRIM varray *HL_NAME(kernel_launch_rets)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  return guard([&]() -> varray * {
    QdContextState &state = require_context(ctx);
    Kernel &kernel_ref = require_kernel(state, kernel);
    if (!kernel->has_return) {
      throw std::runtime_error("Quadrants kernel has no return value");
    }
    LaunchContextBuilder launch_context = kernel_ref.make_launch_context();
    set_kernel_launch_args(state, kernel, args, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*kernel->compiled_kernel_data, launch_context);
    state.program->synchronize_and_assert();
    return make_dynamic_returns(launch_context, kernel->metadata->return_dtypes);
  });
}

HL_PRIM void HL_NAME(kernel_close)(qd_kernel *kernel) {
  guard([&]() { release_kernel_handle(kernel); });
}

DEFINE_PRIM(_VOID, runtime_set_lib_dir, _BYTES);

DEFINE_PRIM(_QD_CONTEXT, context_create, _I32);
DEFINE_PRIM(_QD_CONTEXT, context_create_configured, _I32 _I32);
DEFINE_PRIM(_VOID, context_sync, _QD_CONTEXT);
DEFINE_PRIM(_VOID, context_close, _QD_CONTEXT);
DEFINE_PRIM(_QD_STREAM, stream_create, _QD_CONTEXT);
DEFINE_PRIM(_VOID, stream_sync, _QD_CONTEXT _QD_STREAM);
DEFINE_PRIM(_VOID, stream_close, _QD_STREAM);
DEFINE_PRIM(_VOID, context_set_offline_cache, _QD_CONTEXT _I32 _BYTES);
DEFINE_PRIM(_VOID, context_set_adstack_config, _QD_CONTEXT _I32 _I32 _I32);
DEFINE_PRIM(_VOID, context_set_debug_dump, _QD_CONTEXT _BYTES _I32 _I32 _I32);
DEFINE_PRIM(_VOID, context_set_random_seed, _QD_CONTEXT _I32);
DEFINE_PRIM(_VOID, context_set_cpu_max_num_threads, _QD_CONTEXT _I32);
DEFINE_PRIM(_VOID, context_set_fast_math, _QD_CONTEXT _I32);
DEFINE_PRIM(_VOID, context_set_bounds_check, _QD_CONTEXT _I32);
DEFINE_PRIM(_VOID, profiler_start, _QD_CONTEXT _BYTES);
DEFINE_PRIM(_VOID, profiler_stop, _QD_CONTEXT);
DEFINE_PRIM(_VOID, profiler_clear, _QD_CONTEXT);
DEFINE_PRIM(_F64, profiler_total_time, _QD_CONTEXT);
DEFINE_PRIM(_I32, profiler_query_count, _QD_CONTEXT _BYTES);
DEFINE_PRIM(_F64, profiler_query_avg, _QD_CONTEXT _BYTES);

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
DEFINE_PRIM(_VOID, ndarray_close, _QD_NDARRAY);
DEFINE_PRIM(_VOID, ndarray_write_u64, _QD_CONTEXT _QD_NDARRAY _I32 _I64);
DEFINE_PRIM(_VOID, ndarray_fill_u1, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_I32, ndarray_read_u1, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_u1, _QD_CONTEXT _QD_NDARRAY _I32 _I32);
DEFINE_PRIM(_VOID, ndarray_fill_f32, _QD_CONTEXT _QD_NDARRAY _F64);
DEFINE_PRIM(_VOID, ndarray_fill_f16, _QD_CONTEXT _QD_NDARRAY _F64);
DEFINE_PRIM(_VOID, ndarray_read_bytes, _QD_CONTEXT _QD_NDARRAY _I32 _I32 _I32 _BYTES _I32);
DEFINE_PRIM(_VOID, ndarray_write_bytes, _QD_CONTEXT _QD_NDARRAY _I32 _I32 _I32 _BYTES _I32);
DEFINE_PRIM(_F64, ndarray_read_f32, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_read_f32_bytes, _QD_CONTEXT _QD_NDARRAY _I32 _I32 _BYTES _I32);
DEFINE_PRIM(_VOID, ndarray_write_f32, _QD_CONTEXT _QD_NDARRAY _I32 _F64);
DEFINE_PRIM(_F64, ndarray_read_f16, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_f16, _QD_CONTEXT _QD_NDARRAY _I32 _F64);
DEFINE_PRIM(_VOID, ndarray_fill_f64, _QD_CONTEXT _QD_NDARRAY _F64);
DEFINE_PRIM(_F64, ndarray_read_f64, _QD_CONTEXT _QD_NDARRAY _I32);
DEFINE_PRIM(_VOID, ndarray_write_f64, _QD_CONTEXT _QD_NDARRAY _I32 _F64);

DEFINE_PRIM(_I32, ndarray_supports_zero_copy, _QD_CONTEXT);
DEFINE_PRIM(_I64, ndarray_export_device_pointer, _QD_CONTEXT _QD_NDARRAY);
DEFINE_PRIM(_I64, ndarray_export_dlpack, _QD_CONTEXT _QD_NDARRAY);
DEFINE_PRIM(_VOID, dlpack_release, _I64);
DEFINE_PRIM(_I32, dlpack_device_type, _I64);
DEFINE_PRIM(_I32, dlpack_device_id, _I64);
DEFINE_PRIM(_I32, dlpack_dtype_code, _I64);
DEFINE_PRIM(_I32, dlpack_dtype_bits, _I64);
DEFINE_PRIM(_I32, dlpack_dtype_lanes, _I64);
DEFINE_PRIM(_I32, dlpack_ndim, _I64);
DEFINE_PRIM(_I64, dlpack_shape, _I64 _I32);
DEFINE_PRIM(_I64, dlpack_stride, _I64 _I32);
DEFINE_PRIM(_I64, dlpack_data_pointer, _I64);

DEFINE_PRIM(_QD_SNODE_TREE, snode_tree_create, _QD_CONTEXT);
DEFINE_PRIM(_I32, snode_tree_root_id, _QD_SNODE_TREE);
DEFINE_PRIM(_I32, snode_tree_child, _QD_SNODE_TREE _I32 _I32 _ARR _ARR _I32);
DEFINE_PRIM(_I32, snode_tree_place, _QD_SNODE_TREE _I32 _I32 _BYTES);
DEFINE_PRIM(_I32, snode_tree_commit, _QD_CONTEXT _QD_SNODE_TREE);
DEFINE_PRIM(_VOID, snode_tree_close, _QD_SNODE_TREE);
DEFINE_PRIM(_I32, snode_read_i8, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_i8, _QD_CONTEXT _I32 _ARR _I32);
DEFINE_PRIM(_I32, snode_read_i16, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_i16, _QD_CONTEXT _I32 _ARR _I32);
DEFINE_PRIM(_I32, snode_read_i32, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_i32, _QD_CONTEXT _I32 _ARR _I32);
DEFINE_PRIM(_I64, snode_read_i64, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_i64, _QD_CONTEXT _I32 _ARR _I64);
DEFINE_PRIM(_I32, snode_read_u8, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_u8, _QD_CONTEXT _I32 _ARR _I32);
DEFINE_PRIM(_I32, snode_read_u16, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_u16, _QD_CONTEXT _I32 _ARR _I32);
DEFINE_PRIM(_I64, snode_read_u32, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_u32, _QD_CONTEXT _I32 _ARR _I64);
DEFINE_PRIM(_I64, snode_read_u64, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_u64, _QD_CONTEXT _I32 _ARR _I64);
DEFINE_PRIM(_I32, snode_read_u1, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_u1, _QD_CONTEXT _I32 _ARR _I32);
DEFINE_PRIM(_F64, snode_read_f32, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_f32, _QD_CONTEXT _I32 _ARR _F64);
DEFINE_PRIM(_F64, snode_read_f16, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_f16, _QD_CONTEXT _I32 _ARR _F64);
DEFINE_PRIM(_F64, snode_read_f64, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_VOID, snode_write_f64, _QD_CONTEXT _I32 _ARR _F64);

DEFINE_PRIM(_QD_KERNEL, kernel_compile, _QD_CONTEXT _BYTES _I32 _I32);
DEFINE_PRIM(_VOID, kernel_launch, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_launch_on, _QD_CONTEXT _QD_KERNEL _QD_STREAM _ARR);
DEFINE_PRIM(_VOID, kernel_launch_graph, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_launch_graph_do_while, _QD_CONTEXT _QD_KERNEL _I32 _ARR);
DEFINE_PRIM(_DYN, kernel_launch_ret, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_ARR, kernel_launch_rets, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_close, _QD_KERNEL);
