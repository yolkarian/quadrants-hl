#include "bindings/hashlink/native/quadrants_hl.h"

#include <atomic>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <limits>
#include <memory>
#include <new>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

#include "bindings/hashlink/native/descriptor.h"
#include "quadrants/ir/type.h"
#include "quadrants/ir/type_factory.h"
#include "quadrants/ir/type_utils.h"
#include "quadrants/ir/frontend_ir.h"
#include "quadrants/program/kernel.h"
#include "quadrants/ir/snode.h"
#include "quadrants/program/launch_context_builder.h"
#include "quadrants/program/ndarray.h"
#include "quadrants/program/program.h"
#include "quadrants/rhi/arch.h"
#include "quadrants/rhi/llvm/llvm_device.h"
#include "quadrants/util/lang_util.h"
#include "dlpack/dlpack.h"

#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
#include <cuda_gl_interop.h>
#include <cuda_runtime_api.h>
#include "quadrants/rhi/cuda/cuda_context.h"
#endif

namespace {

using quadrants::Arch;
using quadrants::host_arch;
using quadrants::hashlink::DescriptorDType;
using quadrants::hashlink::ParameterKind;
using quadrants::lang::CompiledKernelData;
using quadrants::lang::Kernel;
using quadrants::lang::LaunchContextBuilder;
using quadrants::lang::Ndarray;
using quadrants::lang::DebugInfo;
using quadrants::lang::Expr;
using quadrants::lang::FieldExpression;
using quadrants::lang::PrimitiveType;
using quadrants::lang::DataType;
using quadrants::lang::PrimitiveTypeID;
using quadrants::lang::Program;
using quadrants::lang::SNode;
using quadrants::lang::SNodeType;
using quadrants::lang::Type;
using quadrants::lang::TypeFactory;

struct QdContextState {
  explicit QdContextState(Arch arch, bool enable_profiler = false) : program(std::make_unique<Program>(arch, enable_profiler)), arch(arch) {
    program->materialize_runtime();
  }

  std::unique_ptr<Program> program;
  Arch arch;
  std::atomic<int> refs{1};
  bool closed{false};
  std::unordered_map<int, int> field_adjoint_snodes;
  std::unordered_map<int, int> field_dual_snodes;
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

struct qd_kernel_specialization {
  std::string key;
  Kernel *kernel{nullptr};
  const CompiledKernelData *compiled_kernel_data{nullptr};
};

struct qd_kernel_metadata {
  std::vector<quadrants::hashlink::ParameterDescriptor> parameters;
  std::vector<DescriptorDType> return_dtypes;
  std::unique_ptr<quadrants::hashlink::KernelDescriptor> descriptor;
  AutodiffMode autodiff_mode{AutodiffMode::kNone};
  std::vector<qd_kernel_specialization> field_specializations;
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
struct qd_event {
  void (*finalize)(qd_event *self){nullptr};
  QdContextState *state{nullptr};
  quadrants::uint64 event_handle{0};
  bool released{false};
};


struct qd_ndarray {
  void (*finalize)(qd_ndarray *self){nullptr};
  QdContextState *state{nullptr};
  Ndarray *array{nullptr};
  qd_ndarray *grad_handle{nullptr};
  qd_ndarray *dual_handle{nullptr};
  bool managed_by_program{true};
  DLManagedTensor *imported_dlpack{nullptr};
  bool released{false};
};

struct qd_snode_tree {
  void (*finalize)(qd_snode_tree *self){nullptr};
  QdContextState *state{nullptr};
  std::unique_ptr<SNode> root;
  bool committed{false};
  bool released{false};
};

struct qd_cuda_gl_resource {
  void (*finalize)(qd_cuda_gl_resource *self){nullptr};
  QdContextState *state{nullptr};
  void *resource{nullptr};
  unsigned int gl_buffer{0};
  int byte_size{0};
  bool mapped{false};
  bool released{false};
};

struct QdSparseEntry {
  int row{0};
  int col{0};
  double value{0.0};
};

struct qd_sparse_matrix {
  void (*finalize)(qd_sparse_matrix *self){nullptr};
  QdContextState *state{nullptr};
  int rows{0};
  int cols{0};
  PrimitiveTypeID dtype{PrimitiveTypeID::f32};
  int storage_format{0};
  std::vector<QdSparseEntry> entries;
  bool released{false};
};

struct qd_sparse_solver {
  void (*finalize)(qd_sparse_solver *self){nullptr};
  QdContextState *state{nullptr};
  PrimitiveTypeID dtype{PrimitiveTypeID::f32};
  std::string solver_type{"LU"};
  std::string ordering{"COLAMD"};
  bool allow_host_dense_fallback{false};
  bool computed{false};
  bool last_info{false};
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
void release_event_handle(qd_event *event) noexcept {
  if (event == nullptr || event->released) {
    return;
  }
  if (event->state != nullptr && event->state->program != nullptr) {
    try {
      event->state->program->stream_manager().destroy_event(event->event_handle);
    } catch (...) {
    }
  }
  release_state(event->state);
  event->state = nullptr;
  event->event_handle = 0;
  event->released = true;
}



void release_ndarray_handle(qd_ndarray *array) noexcept {
  if (array == nullptr || array->released) {
    return;
  }
  array->grad_handle = nullptr;
  array->dual_handle = nullptr;
  if (array->array != nullptr) {
    try {
      if (array->managed_by_program) {
        if (array->state != nullptr && array->state->program != nullptr) {
          array->state->program->delete_ndarray(array->array);
        }
      } else {
        Program *live_program = nullptr;
        if (array->state != nullptr && array->state->program != nullptr) {
          live_program = array->state->program.get();
          live_program->synchronize();
        }
        array->array->detach_program(live_program);
        delete array->array;
      }
    } catch (...) {
    }
  }
  if (array->imported_dlpack != nullptr && array->imported_dlpack->deleter != nullptr) {
    try {
      array->imported_dlpack->deleter(array->imported_dlpack);
    } catch (...) {
    }
  }
  array->array = nullptr;
  array->imported_dlpack = nullptr;
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

void release_cuda_gl_resource_handle(qd_cuda_gl_resource *resource) noexcept {
  if (resource == nullptr || resource->released) {
    return;
  }
#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
  if (resource->resource != nullptr) {
    if (resource->state != nullptr && quadrants::arch_is_cuda(resource->state->arch)) {
      quadrants::lang::CUDAContext::get_instance().make_current();
    }
    auto *cuda_resource = static_cast<cudaGraphicsResource *>(resource->resource);
    if (resource->mapped) {
      cudaGraphicsUnmapResources(1, &cuda_resource, 0);
      resource->mapped = false;
    }
    cudaGraphicsUnregisterResource(cuda_resource);
    resource->resource = nullptr;
  }
#endif
  release_state(resource->state);
  resource->state = nullptr;
  resource->released = true;
}

void release_sparse_matrix_handle(qd_sparse_matrix *matrix) noexcept {
  if (matrix == nullptr || matrix->released) {
    return;
  }
  matrix->entries.clear();
  release_state(matrix->state);
  matrix->state = nullptr;
  matrix->released = true;
}

void release_sparse_solver_handle(qd_sparse_solver *solver) noexcept {
  if (solver == nullptr || solver->released) {
    return;
  }
  release_state(solver->state);
  solver->state = nullptr;
  solver->computed = false;
  solver->last_info = false;
  solver->released = true;
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
void finalize_event(qd_event *event) {
  release_event_handle(event);
  event->~qd_event();
}


void finalize_ndarray(qd_ndarray *array) {
  release_ndarray_handle(array);
  array->~qd_ndarray();
}

void finalize_snode_tree(qd_snode_tree *tree) {
  release_snode_tree_handle(tree);
  tree->~qd_snode_tree();
}

void finalize_cuda_gl_resource(qd_cuda_gl_resource *resource) {
  release_cuda_gl_resource_handle(resource);
  resource->~qd_cuda_gl_resource();
}

void finalize_sparse_matrix(qd_sparse_matrix *matrix) {
  release_sparse_matrix_handle(matrix);
  matrix->~qd_sparse_matrix();
}

void finalize_sparse_solver(qd_sparse_solver *solver) {
  release_sparse_solver_handle(solver);
  solver->~qd_sparse_solver();
}

qd_ndarray *make_ndarray_handle(QdContextState &state,
                               Ndarray *array,
                               bool managed_by_program,
                               DLManagedTensor *imported_dlpack = nullptr) {
  auto *handle = static_cast<qd_ndarray *>(hl_gc_alloc_finalizer(sizeof(qd_ndarray)));
  new (handle) qd_ndarray();
  handle->finalize = finalize_ndarray;
  handle->state = &state;
  handle->array = array;
  handle->managed_by_program = managed_by_program;
  handle->imported_dlpack = imported_dlpack;
  retain_state(&state);
  return handle;
}

qd_sparse_matrix *make_sparse_matrix_handle(QdContextState &state, int rows, int cols, PrimitiveTypeID dtype, int storage_format) {
  auto *handle = static_cast<qd_sparse_matrix *>(hl_gc_alloc_finalizer(sizeof(qd_sparse_matrix)));
  new (handle) qd_sparse_matrix();
  handle->finalize = finalize_sparse_matrix;
  handle->state = &state;
  handle->rows = rows;
  handle->cols = cols;
  handle->dtype = dtype;
  handle->storage_format = storage_format;
  retain_state(&state);
  return handle;
}

qd_sparse_solver *make_sparse_solver_handle(QdContextState &state,
                                            PrimitiveTypeID dtype,
                                            std::string solver_type,
                                            std::string ordering,
                                            bool allow_host_dense_fallback) {
  auto *handle = static_cast<qd_sparse_solver *>(hl_gc_alloc_finalizer(sizeof(qd_sparse_solver)));
  new (handle) qd_sparse_solver();
  handle->finalize = finalize_sparse_solver;
  handle->state = &state;
  handle->dtype = dtype;
  handle->solver_type = std::move(solver_type);
  handle->ordering = std::move(ordering);
  handle->allow_host_dense_fallback = allow_host_dense_fallback;
  retain_state(&state);
  return handle;
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

qd_sparse_matrix &require_sparse_matrix(QdContextState &state, qd_sparse_matrix *matrix) {
  if (matrix == nullptr || matrix->state == nullptr || matrix->released) {
    throw std::runtime_error("Quadrants sparse matrix handle is closed");
  }
  if (matrix->state != &state) {
    throw std::runtime_error("Quadrants sparse matrix belongs to a different context");
  }
  return *matrix;
}

qd_sparse_solver &require_sparse_solver(QdContextState &state, qd_sparse_solver *solver) {
  if (solver == nullptr || solver->state == nullptr || solver->released) {
    throw std::runtime_error("Quadrants sparse solver handle is closed");
  }
  if (solver->state != &state) {
    throw std::runtime_error("Quadrants sparse solver belongs to a different context");
  }
  return *solver;
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
qd_event &require_event(QdContextState &state, qd_event *event) {
  if (event == nullptr || event->state == nullptr || event->released) {
    throw std::runtime_error("Quadrants stream event is closed");
  }
  if (event->state != &state) {
    throw std::runtime_error("Quadrants stream event belongs to a different context");
  }
  return *event;
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

qd_ndarray &require_ndarray_handle(qd_ndarray *array, const char *name) {
  if (array == nullptr || array->state == nullptr || array->released || array->array == nullptr) {
    throw std::runtime_error(std::string("Quadrants ") + name + " ndarray handle is closed");
  }
  return *array;
}

qd_ndarray *autodiff_peer_handle_for_kernel(qd_ndarray *array_handle, const Kernel &kernel_ref) {
  switch (kernel_ref.autodiff_mode) {
    case AutodiffMode::kForward:
      return array_handle->dual_handle;
    case AutodiffMode::kReverse:
    case AutodiffMode::kCheckAutodiffValid:
      return array_handle->grad_handle;
    case AutodiffMode::kNone:
      return array_handle->grad_handle;
  }
  return nullptr;
}

const char *required_autodiff_storage_name(const Kernel &kernel_ref) {
  return kernel_ref.autodiff_mode == AutodiffMode::kForward ? "dual" : "grad";
}
void require_kernel_handle(QdContextState &state, qd_kernel *kernel) {
  if (kernel == nullptr || kernel->state == nullptr || kernel->released || kernel->metadata == nullptr) {
    throw std::runtime_error("Quadrants kernel handle is closed");
  }
  if (kernel->state != &state) {
    throw std::runtime_error("Quadrants kernel belongs to a different context");
  }
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

class RegisteredFieldGradInfo final : public SNode::GradInfoProvider {
 public:
  RegisteredFieldGradInfo(SNodeGradType grad_type, SNode *adjoint, SNode *dual)
      : grad_type_(grad_type), adjoint_(adjoint), dual_(dual) {
  }

  bool is_primal() const override {
    return grad_type_ == SNodeGradType::kPrimal;
  }

  SNodeGradType get_snode_grad_type() const override {
    return grad_type_;
  }

  SNode *adjoint_snode() const override {
    return adjoint_;
  }

  SNode *dual_snode() const override {
    return dual_;
  }

  SNode *adjoint_checkbit_snode() const override {
    return nullptr;
  }

 private:
  SNodeGradType grad_type_;
  SNode *adjoint_{nullptr};
  SNode *dual_{nullptr};
};

SNode *registered_peer_snode(QdContextState &state, const std::unordered_map<int, int> &registry, int primal_snode_id) {
  auto it = registry.find(primal_snode_id);
  if (it == registry.end()) {
    return nullptr;
  }
  return state.program->get_snode_by_id(it->second);
}

void refresh_registered_field_grad_info(QdContextState &state, int primal_snode_id) {
  SNode &primal = require_committed_place_snode(state, primal_snode_id);
  SNode *adjoint = registered_peer_snode(state, state.field_adjoint_snodes, primal_snode_id);
  SNode *dual = registered_peer_snode(state, state.field_dual_snodes, primal_snode_id);
  primal.grad_info = std::make_unique<RegisteredFieldGradInfo>(SNodeGradType::kPrimal, adjoint, dual);
  if (adjoint != nullptr) {
    adjoint->grad_info = std::make_unique<RegisteredFieldGradInfo>(SNodeGradType::kAdjoint, nullptr, nullptr);
  }
  if (dual != nullptr) {
    dual->grad_info = std::make_unique<RegisteredFieldGradInfo>(SNodeGradType::kDual, nullptr, nullptr);
  }
}

void register_field_peer(QdContextState &state,
                         int primal_snode_id,
                         int peer_snode_id,
                         std::unordered_map<int, int> &registry,
                         const char *peer_name) {
  SNode &primal = require_committed_place_snode(state, primal_snode_id);
  SNode &peer = require_committed_place_snode(state, peer_snode_id);
  if (primal.dt->get_compute_type() != peer.dt->get_compute_type()) {
    throw std::runtime_error(std::string("Quadrants Field ") + peer_name + " dtype mismatch");
  }
  if (primal.num_active_indices != peer.num_active_indices) {
    throw std::runtime_error(std::string("Quadrants Field ") + peer_name + " rank mismatch");
  }
  registry[primal_snode_id] = peer_snode_id;
  refresh_registered_field_grad_info(state, primal_snode_id);
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
    case 6:
      return SNodeType::quant_array;
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
  if (snode_type == SNodeType::quant_array) {
    if (axis_values.empty() || size_values.empty()) {
      throw std::runtime_error("Quadrants quant_array SNode requires at least one axis and size");
    }
    if (chunk_size <= 0 || chunk_size > 64) {
      throw std::runtime_error("Quadrants quant_array max bit width must be in 1...64");
    }
    return parent.quant_array(axis_values, size_values, chunk_size);
  }
  return parent.create_node(std::move(axis_values), std::move(size_values), snode_type);
}

Type *quant_type_from_bridge(int quant_kind,
                             int bits,
                             int is_signed,
                             int compute_dtype,
                             int fractional_bits,
                             double scale) {
  if (bits <= 0 || bits > 64) {
    throw std::runtime_error("Quadrants quant bit width must be in 1...64");
  }
  TypeFactory &factory = TypeFactory::get_instance();
  Type *compute_type = dtype_from_bridge_id(compute_dtype);
  const bool signed_storage = is_signed != 0;
  switch (quant_kind) {
    case 1:
      if (!quadrants::lang::is_integral(compute_type)) {
        throw std::runtime_error("Quadrants quant int compute dtype must be integral");
      }
      return factory.get_quant_int_type(bits, signed_storage, compute_type);
    case 2: {
      if (!quadrants::lang::is_real(compute_type)) {
        throw std::runtime_error("Quadrants quant fixed compute dtype must be floating point");
      }
      if (fractional_bits < 0 || fractional_bits >= bits) {
        throw std::runtime_error("Quadrants quant fixed fractional bits must be within storage bit width");
      }
      if (scale <= 0.0) {
        throw std::runtime_error("Quadrants quant fixed scale must be positive");
      }
      Type *digits_type = factory.get_quant_int_type(bits, signed_storage, nullptr);
      return factory.get_quant_fixed_type(digits_type, compute_type, scale);
    }
    case 3:
      throw std::runtime_error("Quadrants quant float placement requires bit_struct metadata and is not supported by this HashLink bridge");
    default:
      throw std::runtime_error("Unsupported Quadrants quant kind id: " + std::to_string(quant_kind));
  }
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
void require_snode_matches_ndarray_shape(SNode &snode, const Ndarray &array) {
  if (static_cast<std::size_t>(snode.num_active_indices) != array.shape.size()) {
    throw std::runtime_error("Quadrants field/tensor mirror rank mismatch");
  }
  for (int axis = 0; axis < snode.num_active_indices; ++axis) {
    if (snode.shape_along_axis(axis) != array.shape[static_cast<std::size_t>(axis)]) {
      throw std::runtime_error("Quadrants field/tensor mirror shape mismatch");
    }
  }
}

std::vector<int> snode_shape(SNode &snode) {
  std::vector<int> shape;
  shape.reserve(snode.num_active_indices);
  for (int axis = 0; axis < snode.num_active_indices; ++axis) {
    shape.push_back(snode.shape_along_axis(axis));
  }
  return shape;
}

std::vector<int> flat_to_indices(const std::vector<int> &shape, std::size_t flat_index) {
  std::vector<int> indices(shape.size(), 0);
  for (std::size_t axis = shape.size(); axis > 0; --axis) {
    const std::size_t current = axis - 1;
    const std::size_t dim = static_cast<std::size_t>(shape[current]);
    indices[current] = static_cast<int>(flat_index % dim);
    flat_index /= dim;
  }
  return indices;
}

void fill_snode_int(QdContextState &state, int snode_id, int64 value) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  auto shape = snode_shape(snode);
  std::size_t total = 1;
  for (int dim : shape) {
    total *= static_cast<std::size_t>(dim);
  }
  for (std::size_t i = 0; i < total; ++i) {
    snode.write_int(flat_to_indices(shape, i), value);
  }
}

void fill_snode_uint(QdContextState &state, int snode_id, quadrants::uint64 value) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  auto shape = snode_shape(snode);
  std::size_t total = 1;
  for (int dim : shape) {
    total *= static_cast<std::size_t>(dim);
  }
  for (std::size_t i = 0; i < total; ++i) {
    snode.write_uint(flat_to_indices(shape, i), value);
  }
}

void fill_snode_float(QdContextState &state, int snode_id, double value) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  auto shape = snode_shape(snode);
  std::size_t total = 1;
  for (int dim : shape) {
    total *= static_cast<std::size_t>(dim);
  }
  for (std::size_t i = 0; i < total; ++i) {
    snode.write_float(flat_to_indices(shape, i), value);
  }
}

void copy_snode_to_ndarray(QdContextState &state, int snode_id, PrimitiveTypeID dtype, qd_ndarray *arr) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  Ndarray &array = require_typed_ndarray(state, arr, dtype);
  require_snode_matches_ndarray_shape(snode, array);
  for (std::size_t i = 0; i < array.get_nelement(); ++i) {
    auto indices = flat_to_indices(array, static_cast<int>(i));
    switch (dtype) {
      case PrimitiveTypeID::i8:
      case PrimitiveTypeID::i16:
      case PrimitiveTypeID::i32:
      case PrimitiveTypeID::i64:
        array.write_int(indices, snode.read_int(indices));
        break;
      case PrimitiveTypeID::u8:
      case PrimitiveTypeID::u16:
      case PrimitiveTypeID::u32:
      case PrimitiveTypeID::u64:
        array.write_int(indices, static_cast<int64>(snode.read_uint(indices)));
        break;
      case PrimitiveTypeID::u1:
        array.write_int(indices, snode.read_uint(indices) != 0 ? 1 : 0);
        break;
      case PrimitiveTypeID::f16:
      case PrimitiveTypeID::f32:
      case PrimitiveTypeID::f64:
        array.write_float(indices, snode.read_float(indices));
        break;
      default:
        throw std::runtime_error("Unsupported Quadrants field dtype for copy-to-ndarray");
    }
  }
}

void copy_ndarray_to_snode(QdContextState &state, int snode_id, PrimitiveTypeID dtype, qd_ndarray *arr) {
  SNode &snode = require_committed_place_snode(state, snode_id);
  Ndarray &array = require_typed_ndarray(state, arr, dtype);
  require_snode_matches_ndarray_shape(snode, array);
  for (std::size_t i = 0; i < array.get_nelement(); ++i) {
    auto indices = flat_to_indices(array, static_cast<int>(i));
    switch (dtype) {
      case PrimitiveTypeID::i8:
      case PrimitiveTypeID::i16:
      case PrimitiveTypeID::i32:
      case PrimitiveTypeID::i64:
        snode.write_int(indices, array.read_int(indices));
        break;
      case PrimitiveTypeID::u8:
      case PrimitiveTypeID::u16:
      case PrimitiveTypeID::u32:
      case PrimitiveTypeID::u64:
        snode.write_uint(indices, array.read_uint(indices));
        break;
      case PrimitiveTypeID::u1:
        snode.write_int(indices, array.read_uint(indices) != 0 ? 1 : 0);
        break;
      case PrimitiveTypeID::f16:
      case PrimitiveTypeID::f32:
      case PrimitiveTypeID::f64:
        snode.write_float(indices, array.read_float(indices));
        break;
      default:
        throw std::runtime_error("Unsupported Quadrants field dtype for copy-from-ndarray");
    }
  }
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
int bridge_dtype_from_dlpack(const DLDataType &dtype) {
  if (dtype.lanes != 1) {
    throw std::runtime_error("Quadrants DLPack import requires a scalar-lane tensor");
  }
  if (dtype.code == static_cast<std::uint8_t>(kDLInt)) {
    switch (dtype.bits) {
      case 8:
        return 0;
      case 16:
        return 1;
      case 32:
        return 2;
      case 64:
        return 3;
    }
  }
  if (dtype.code == static_cast<std::uint8_t>(kDLUInt)) {
    switch (dtype.bits) {
      case 8:
        return 4;
      case 16:
        return 5;
      case 32:
        return 6;
      case 64:
        return 7;
    }
  }
  if (dtype.code == static_cast<std::uint8_t>(kDLFloat)) {
    switch (dtype.bits) {
      case 16:
        return 11;
      case 32:
        return 8;
      case 64:
        return 9;
    }
  }
  if (dtype.code == static_cast<std::uint8_t>(kDLBool) && dtype.bits == 8) {
    return 10;
  }
  throw std::runtime_error("Quadrants DLPack import dtype is unsupported");
}

void require_dlpack_device_matches_context(const DLManagedTensor *managed, Arch arch) {
  const auto expected = dl_device_type_from_arch(arch);
  if (managed->dl_tensor.device.device_type != expected) {
    throw std::runtime_error("Quadrants DLPack device type does not match the target context");
  }
  if (managed->dl_tensor.device.device_id != 0) {
    throw std::runtime_error("Quadrants DLPack device id does not match the target context");
  }
}

std::vector<int> dlpack_shape_to_ints(const DLManagedTensor *managed) {
  if (managed->dl_tensor.ndim <= 0) {
    throw std::runtime_error("Quadrants DLPack import requires at least one dimension");
  }
  std::vector<int> shape;
  shape.reserve(static_cast<std::size_t>(managed->dl_tensor.ndim));
  for (int axis = 0; axis < managed->dl_tensor.ndim; ++axis) {
    const int64 dim = managed->dl_tensor.shape[axis];
    if (dim <= 0) {
      throw std::runtime_error("Quadrants DLPack import requires positive dimensions");
    }
    if (dim > std::numeric_limits<int>::max()) {
      throw std::runtime_error("Quadrants DLPack import dimension exceeds Haxe Int range");
    }
    shape.push_back(static_cast<int>(dim));
  }
  return shape;
}

void require_contiguous_dlpack(const DLManagedTensor *managed, const std::vector<int> &shape) {
  if (managed->dl_tensor.strides == nullptr) {
    return;
  }
  int64 expected = 1;
  for (int axis = static_cast<int>(shape.size()) - 1; axis >= 0; --axis) {
    if (managed->dl_tensor.strides[axis] != expected) {
      throw std::runtime_error("Quadrants DLPack import requires a contiguous row-major tensor");
    }
    expected *= shape[static_cast<std::size_t>(axis)];
  }
}

quadrants::lang::LlvmDevice &require_llvm_device(QdContextState &state, const char *what) {
  if (!quadrants::arch_uses_llvm(state.arch)) {
    throw std::runtime_error(std::string("Quadrants ") + what + " requires an LLVM-backed context");
  }
  auto *device = dynamic_cast<quadrants::lang::LlvmDevice *>(state.program->get_compute_device());
  if (device == nullptr) {
    throw std::runtime_error(std::string("Quadrants ") + what + " requires an LLVM device");
  }
  return *device;
}

void *checked_external_data_ptr(const DLManagedTensor *managed) {
  auto *base = static_cast<std::uint8_t *>(managed->dl_tensor.data);
  if (base == nullptr) {
    throw std::runtime_error("Quadrants DLPack import data pointer is null");
  }
  return base + managed->dl_tensor.byte_offset;
}

std::size_t checked_import_byte_size(const std::vector<int> &shape, int bridge_dtype) {
  std::size_t count = 1;
  for (int dim : shape) {
    const std::size_t size_dim = static_cast<std::size_t>(dim);
    if (count > std::numeric_limits<std::size_t>::max() / size_dim) {
      throw std::runtime_error("Quadrants external import shape overflows size_t");
    }
    count *= size_dim;
  }
  const std::size_t element_size = static_cast<std::size_t>(quadrants::lang::data_type_size(dtype_from_bridge_id(bridge_dtype)));
  if (count > std::numeric_limits<std::size_t>::max() / element_size) {
    throw std::runtime_error("Quadrants external import byte size overflows size_t");
  }
  return count * element_size;
}

unsigned int checked_gl_buffer_id(vdynamic *buffer) {
  if (buffer == nullptr) {
    throw std::runtime_error("Quadrants CUDA/GL interop received a null OpenGL buffer handle");
  }
  if (buffer->t == nullptr) {
    throw std::runtime_error("Quadrants CUDA/GL interop received an invalid OpenGL buffer handle");
  }
  const hl_type_kind kind = buffer->t->kind;
  if (kind != HI32 &&
      !(kind == HNULL && buffer->t->tparam != nullptr && buffer->t->tparam->kind == HI32)) {
    throw std::runtime_error("Quadrants CUDA/GL interop OpenGL buffer handle must be an Int");
  }
  if (buffer->v.i == 0) {
    throw std::runtime_error("Quadrants CUDA/GL interop OpenGL buffer handle must be a non-zero buffer object name");
  }
  return static_cast<unsigned int>(buffer->v.i);
}

void require_cuda_gl_interop_context(QdContextState &state) {
  if (!quadrants::arch_is_cuda(state.arch)) {
    throw std::runtime_error("Quadrants CUDA/GL interop requires a CUDA context");
  }
#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
  quadrants::lang::CUDAContext::get_instance().make_current();
#else
  throw std::runtime_error("Quadrants CUDA/GL interop was not built with CUDA toolkit support");
#endif
}

#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
void check_cuda_gl(cudaError_t err, const char *what) {
  if (err == cudaSuccess) {
    return;
  }
  throw std::runtime_error(std::string("Quadrants ") + what + ": " + cudaGetErrorString(err));
}

cudaGraphicsResource *checked_cuda_gl_resource(qd_cuda_gl_resource *resource) {
  if (resource == nullptr || resource->released || resource->resource == nullptr) {
    throw std::runtime_error("Quadrants CUDA/GL resource is closed");
  }
  return static_cast<cudaGraphicsResource *>(resource->resource);
}
#endif


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

bool profiler_enabled(QdContextState &state) {
  return state.program->get_profiler() != nullptr;
}

std::string bytes_to_string(vbyte *bytes) {
  return bytes == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(bytes));
}

std::vector<std::string> strings_from_hl_array(varray *values, const char *name) {
  if (values == nullptr) {
    throw std::runtime_error(std::string("Quadrants ") + name + " array is null");
  }
  vbyte **items = hl_aptr(values, vbyte *);
  std::vector<std::string> result;
  result.reserve(static_cast<std::size_t>(values->size));
  for (int i = 0; i < values->size; ++i) {
    if (items[i] == nullptr) {
      throw std::runtime_error(std::string("Quadrants ") + name + " entry is null");
    }
    result.emplace_back(reinterpret_cast<const char *>(items[i]));
  }
  return result;
}

void require_sparse_index(const qd_sparse_matrix &matrix, int row, int col) {
  if (row < 0 || row >= matrix.rows || col < 0 || col >= matrix.cols) {
    throw std::runtime_error("Quadrants sparse matrix index out of bounds");
  }
}

bool sparse_supported_dtype(PrimitiveTypeID dtype) {
  return dtype == PrimitiveTypeID::f32 || dtype == PrimitiveTypeID::f64;
}

void require_sparse_dtype(const qd_sparse_matrix &matrix, PrimitiveTypeID dtype) {
  if (matrix.dtype != dtype) {
    throw std::runtime_error("Quadrants sparse bridge matrix dtype mismatch");
  }
}

void require_sparse_supported_dtype(PrimitiveTypeID dtype) {
  if (!sparse_supported_dtype(dtype)) {
    throw std::runtime_error("Quadrants sparse bridge currently supports F32 and F64 matrices");
  }
}

void require_sparse_storage_format(int storage_format) {
  if (storage_format != 0 && storage_format != 1) {
    throw std::runtime_error("Quadrants sparse matrix storage format is unsupported");
  }
}

bool is_supported_solver_type(const std::string &solver_type) {
  return solver_type == "LLT" || solver_type == "LDLT" || solver_type == "LU";
}

bool is_supported_sparse_ordering(const std::string &ordering) {
  return ordering == "AMD" || ordering == "COLAMD" || ordering == "NATURAL";
}

void require_supported_sparse_solver_options(const std::string &solver_type, const std::string &ordering) {
  if (!is_supported_solver_type(solver_type)) {
    throw std::runtime_error("Quadrants sparse solver type is unsupported");
  }
  if (!is_supported_sparse_ordering(ordering)) {
    throw std::runtime_error("Quadrants sparse solver ordering is unsupported");
  }
}

void require_host_dense_fallback_enabled(const qd_sparse_solver &solver) {
  if (!solver.allow_host_dense_fallback) {
    throw std::runtime_error("Quadrants native sparse solver backend is unavailable; enable host dense fallback explicitly");
  }
}

int sparse_entry_index(const qd_sparse_matrix &matrix, int row, int col) {
  for (std::size_t i = 0; i < matrix.entries.size(); ++i) {
    if (matrix.entries[i].row == row && matrix.entries[i].col == col) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

double sparse_get_value(const qd_sparse_matrix &matrix, int row, int col) {
  const int index = sparse_entry_index(matrix, row, col);
  return index < 0 ? 0.0 : matrix.entries[static_cast<std::size_t>(index)].value;
}

void sparse_set_value(qd_sparse_matrix &matrix, int row, int col, double value) {
  require_sparse_index(matrix, row, col);
  const int index = sparse_entry_index(matrix, row, col);
  if (value == 0.0) {
    if (index >= 0) {
      matrix.entries.erase(matrix.entries.begin() + index);
    }
    return;
  }
  if (index >= 0) {
    matrix.entries[static_cast<std::size_t>(index)].value = value;
  } else {
    matrix.entries.push_back({row, col, value});
  }
}

std::vector<double> dense_from_sparse(const qd_sparse_matrix &matrix) {
  std::vector<double> dense(static_cast<std::size_t>(matrix.rows) * static_cast<std::size_t>(matrix.cols), 0.0);
  for (const auto &entry : matrix.entries) {
    dense[static_cast<std::size_t>(entry.row) * static_cast<std::size_t>(matrix.cols) + static_cast<std::size_t>(entry.col)] +=
        entry.value;
  }
  return dense;
}


double read_sparse_flat(Ndarray &array, int index) {
  return array.read_float(flat_to_indices(array, index));
}

void write_sparse_flat(Ndarray &array, int index, double value) {
  array.write_float(flat_to_indices(array, index), value);
}

std::vector<double> read_sparse_vector(QdContextState &state,
                                       qd_ndarray *handle,
                                       PrimitiveTypeID dtype,
                                       int length,
                                       const char *name) {
  Ndarray &array = require_typed_ndarray(state, handle, dtype);
  if (array.get_nelement() < static_cast<std::size_t>(length)) {
    throw std::runtime_error(std::string("Quadrants sparse ") + name + " vector is too small");
  }
  std::vector<double> values(static_cast<std::size_t>(length), 0.0);
  for (int i = 0; i < length; ++i) {
    values[static_cast<std::size_t>(i)] = read_sparse_flat(array, i);
  }
  return values;
}

void write_sparse_vector(QdContextState &state,
                         qd_ndarray *handle,
                         PrimitiveTypeID dtype,
                         const std::vector<double> &values,
                         const char *name) {
  Ndarray &array = require_typed_ndarray(state, handle, dtype);
  if (array.get_nelement() < values.size()) {
    throw std::runtime_error(std::string("Quadrants sparse ") + name + " vector is too small");
  }
  for (std::size_t i = 0; i < values.size(); ++i) {
    write_sparse_flat(array, static_cast<int>(i), values[i]);
  }
}

bool solve_dense_system(std::vector<double> matrix, std::vector<double> rhs, int n, std::vector<double> &solution) {
  if (n <= 0) {
    return false;
  }
  for (int pivot = 0; pivot < n; ++pivot) {
    int best = pivot;
    double best_abs = std::fabs(matrix[static_cast<std::size_t>(pivot) * n + pivot]);
    for (int row = pivot + 1; row < n; ++row) {
      const double candidate = std::fabs(matrix[static_cast<std::size_t>(row) * n + pivot]);
      if (candidate > best_abs) {
        best = row;
        best_abs = candidate;
      }
    }
    if (best_abs <= 1.0e-12) {
      return false;
    }
    if (best != pivot) {
      for (int col = pivot; col < n; ++col) {
        std::swap(matrix[static_cast<std::size_t>(pivot) * n + col], matrix[static_cast<std::size_t>(best) * n + col]);
      }
      std::swap(rhs[static_cast<std::size_t>(pivot)], rhs[static_cast<std::size_t>(best)]);
    }
    for (int row = pivot + 1; row < n; ++row) {
      const double factor = matrix[static_cast<std::size_t>(row) * n + pivot] /
                            matrix[static_cast<std::size_t>(pivot) * n + pivot];
      if (factor == 0.0) {
        continue;
      }
      matrix[static_cast<std::size_t>(row) * n + pivot] = 0.0;
      for (int col = pivot + 1; col < n; ++col) {
        matrix[static_cast<std::size_t>(row) * n + col] -=
            factor * matrix[static_cast<std::size_t>(pivot) * n + col];
      }
      rhs[static_cast<std::size_t>(row)] -= factor * rhs[static_cast<std::size_t>(pivot)];
    }
  }
  solution.assign(static_cast<std::size_t>(n), 0.0);
  for (int row = n - 1; row >= 0; --row) {
    double value = rhs[static_cast<std::size_t>(row)];
    for (int col = row + 1; col < n; ++col) {
      value -= matrix[static_cast<std::size_t>(row) * n + col] * solution[static_cast<std::size_t>(col)];
    }
    solution[static_cast<std::size_t>(row)] = value / matrix[static_cast<std::size_t>(row) * n + row];
  }
  return true;
}

double dot(const std::vector<double> &lhs, const std::vector<double> &rhs) {
  double total = 0.0;
  for (std::size_t i = 0; i < lhs.size(); ++i) {
    total += lhs[i] * rhs[i];
  }
  return total;
}

std::vector<double> sparse_matvec_host(const qd_sparse_matrix &matrix, const std::vector<double> &x) {
  std::vector<double> y(static_cast<std::size_t>(matrix.rows), 0.0);
  for (const auto &entry : matrix.entries) {
    y[static_cast<std::size_t>(entry.row)] += entry.value * x[static_cast<std::size_t>(entry.col)];
  }
  return y;
}

int sparse_cg_solve_host(QdContextState &state,
                         qd_sparse_matrix &matrix_ref,
                         qd_ndarray *b,
                         qd_ndarray *x,
                         int max_iterations,
                         double tolerance) {
  if (max_iterations <= 0) {
    throw std::runtime_error("Quadrants sparse CG max iterations must be positive");
  }
  if (tolerance <= 0.0) {
    throw std::runtime_error("Quadrants sparse CG tolerance must be positive");
  }
  require_sparse_supported_dtype(matrix_ref.dtype);
  if (matrix_ref.rows != matrix_ref.cols) {
    throw std::runtime_error("Quadrants sparse CG requires a square matrix");
  }
  std::vector<double> rhs = read_sparse_vector(state, b, matrix_ref.dtype, matrix_ref.rows, "rhs");
  std::vector<double> solution(static_cast<std::size_t>(matrix_ref.rows), 0.0);
  std::vector<double> residual = rhs;
  std::vector<double> direction = residual;
  double residual_sq = dot(residual, residual);
  const double tolerance_sq = tolerance * tolerance;
  int iterations = 0;
  while (iterations < max_iterations && residual_sq > tolerance_sq) {
    std::vector<double> ad = sparse_matvec_host(matrix_ref, direction);
    const double denom = dot(direction, ad);
    if (std::fabs(denom) <= 1.0e-20) {
      break;
    }
    const double alpha = residual_sq / denom;
    for (std::size_t i = 0; i < solution.size(); ++i) {
      solution[i] += alpha * direction[i];
      residual[i] -= alpha * ad[i];
    }
    const double next_residual_sq = dot(residual, residual);
    if (next_residual_sq <= tolerance_sq) {
      residual_sq = next_residual_sq;
      ++iterations;
      break;
    }
    const double beta = next_residual_sq / residual_sq;
    for (std::size_t i = 0; i < direction.size(); ++i) {
      direction[i] = residual[i] + beta * direction[i];
    }
    residual_sq = next_residual_sq;
    ++iterations;
  }
  write_sparse_vector(state, x, matrix_ref.dtype, solution, "solution");
  return residual_sq <= tolerance_sq ? iterations : (iterations == 0 ? -1 : -iterations);
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

bool has_field_parameters(const std::vector<quadrants::hashlink::ParameterDescriptor> &parameters) {
  for (const auto &param : parameters) {
    if (param.kind == ParameterKind::field) {
      return true;
    }
  }
  return false;
}

int dynamic_to_field_snode_id(vdynamic *value) {
  if (value == nullptr) {
    throw std::runtime_error("Quadrants Field kernel argument is null");
  }
  return hl_dyn_casti(&value, &hlt_dyn, &hlt_i32);
}

std::vector<int> collect_field_snode_ids(qd_kernel *kernel, varray *args) {
  if (args == nullptr) {
    throw std::runtime_error("Quadrants kernel argument array is null");
  }
  const auto &parameters = kernel->metadata->parameters;
  if (args->size != static_cast<int>(parameters.size())) {
    throw std::runtime_error("Quadrants kernel argument count mismatch");
  }
  vdynamic **values = hl_aptr(args, vdynamic *);
  std::vector<int> ids(parameters.size(), -1);
  for (std::size_t i = 0; i < parameters.size(); ++i) {
    if (parameters[i].kind == ParameterKind::field) {
      ids[i] = dynamic_to_field_snode_id(values[i]);
    }
  }
  return ids;
}

std::vector<int> collect_field_peer_snode_ids(
    const std::vector<quadrants::hashlink::ParameterDescriptor> &parameters,
    const std::vector<int> &field_snode_ids,
    const std::unordered_map<int, int> &registered_peers) {
  std::vector<int> peer_ids(parameters.size(), -1);
  for (std::size_t i = 0; i < parameters.size(); ++i) {
    if (parameters[i].kind != ParameterKind::field) {
      continue;
    }
    auto it = registered_peers.find(field_snode_ids[i]);
    if (it != registered_peers.end()) {
      peer_ids[i] = it->second;
    }
  }
  return peer_ids;
}

void append_field_key_part(std::string &key, const char *tag, const std::vector<int> &ids) {
  key.push_back('|');
  key += tag;
  key.push_back('=');
  for (std::size_t i = 0; i < ids.size(); ++i) {
    if (i != 0) {
      key.push_back(',');
    }
    key += std::to_string(ids[i]);
  }
}


std::string field_specialization_key(const std::vector<int> &field_snode_ids,
                                     const std::vector<int> &field_adjoint_snode_ids,
                                     const std::vector<int> &field_dual_snode_ids) {
  std::string key;
  append_field_key_part(key, "field", field_snode_ids);
  append_field_key_part(key, "adjoint", field_adjoint_snode_ids);
  append_field_key_part(key, "dual", field_dual_snode_ids);
  return key;
}

struct ResolvedKernel {
  Kernel *kernel{nullptr};
  const CompiledKernelData *compiled_kernel_data{nullptr};
};

ResolvedKernel resolve_kernel_for_launch(QdContextState &state, qd_kernel *kernel, varray *args) {
  require_kernel_handle(state, kernel);
  if (kernel->metadata->descriptor == nullptr) {
    return ResolvedKernel{kernel->kernel, kernel->compiled_kernel_data};
  }
  std::vector<int> field_snode_ids = collect_field_snode_ids(kernel, args);
  std::vector<int> field_adjoint_snode_ids =
      collect_field_peer_snode_ids(kernel->metadata->parameters, field_snode_ids, state.field_adjoint_snodes);
  std::vector<int> field_dual_snode_ids =
      collect_field_peer_snode_ids(kernel->metadata->parameters, field_snode_ids, state.field_dual_snodes);
  const std::string key = field_specialization_key(field_snode_ids, field_adjoint_snode_ids, field_dual_snode_ids);
  for (auto &specialization : kernel->metadata->field_specializations) {
    if (specialization.key == key) {
      kernel->kernel = specialization.kernel;
      kernel->compiled_kernel_data = specialization.compiled_kernel_data;
      return ResolvedKernel{specialization.kernel, specialization.compiled_kernel_data};
    }
  }
  BlockingSection blocking;
  quadrants::hashlink::KernelBuildResult result = quadrants::hashlink::build_kernel_from_descriptor(
      *state.program, *kernel->metadata->descriptor, kernel->metadata->autodiff_mode, &field_snode_ids,
      &field_adjoint_snode_ids, &field_dual_snode_ids);
  kernel->metadata->field_specializations.push_back(qd_kernel_specialization{key, result.kernel, result.compiled_kernel_data});
  kernel->kernel = result.kernel;
  kernel->compiled_kernel_data = result.compiled_kernel_data;
  return ResolvedKernel{result.kernel, result.compiled_kernel_data};
}

void set_kernel_launch_args(QdContextState &state,
                            qd_kernel *kernel,
                            varray *args,
                            Kernel &kernel_ref,
                            LaunchContextBuilder &launch_context) {
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
      continue;
    }
    if (param.kind == ParameterKind::field) {
      const int snode_id = dynamic_to_field_snode_id(values[i]);
      if (state.program->get_snode_by_id(snode_id) == nullptr) {
        throw std::runtime_error("Quadrants Field kernel argument is not part of this context");
      }
      launch_context.set_arg_int(static_cast<int>(i), snode_id);
      continue;
    }

    qd_ndarray *array_handle = dynamic_to_ndarray(values[i]);
    Ndarray &array = require_ndarray(state, array_handle);
    if (param.rank != array.shape.size()) {
      throw std::runtime_error("Quadrants ndarray kernel argument rank mismatch");
    }
    const auto dtype = primitive_id_from_descriptor_dtype(param.dtype);
    require_array_dtype(array, dtype);

    if (!param.needs_grad()) {
      launch_context.set_arg_ndarray(static_cast<int>(i), array);
      continue;
    }

    qd_ndarray *peer_handle = autodiff_peer_handle_for_kernel(array_handle, kernel_ref);
    if (peer_handle == nullptr) {
      if (kernel_ref.autodiff_mode != AutodiffMode::kNone) {
        throw std::runtime_error(std::string("Quadrants autodiff kernel requires tensor ") +
                                 required_autodiff_storage_name(kernel_ref) + " storage");
      }
      launch_context.set_arg_ndarray_impl(static_cast<int>(i), array.get_device_allocation_ptr_as_int(), array.shape, 0);
      continue;
    }

    Ndarray &peer_array = require_ndarray(state, peer_handle);
    if (peer_array.shape != array.shape) {
      throw std::runtime_error(std::string("Quadrants tensor ") + required_autodiff_storage_name(kernel_ref) +
                               " storage shape mismatch");
    }
    require_array_dtype(peer_array, dtype);
    launch_context.set_arg_ndarray_impl(static_cast<int>(i),
                                        array.get_device_allocation_ptr_as_int(),
                                        array.shape,
                                        peer_array.get_device_allocation_ptr_as_int());
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
HL_PRIM int HL_NAME(stream_supports_events)(qd_context *ctx) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return (quadrants::arch_is_cuda(state.arch) || quadrants::arch_is_amdgpu(state.arch)) ? 1 : 0;
  });
}

HL_PRIM qd_event *HL_NAME(stream_event_create)(qd_context *ctx) {
  return guard([&]() -> qd_event * {
    QdContextState &state = require_context(ctx);
    if (!quadrants::arch_is_cuda(state.arch) && !quadrants::arch_is_amdgpu(state.arch)) {
      throw std::runtime_error("Quadrants stream events require a CUDA or AMDGPU context");
    }
    BlockingSection blocking;
    auto *handle = static_cast<qd_event *>(hl_gc_alloc_finalizer(sizeof(qd_event)));
    new (handle) qd_event();
    handle->finalize = finalize_event;
    handle->state = &state;
    handle->event_handle = state.program->stream_manager().create_event();
    retain_state(&state);
    return handle;
  });
}

HL_PRIM void HL_NAME(stream_event_record)(qd_context *ctx, qd_event *event, qd_stream *stream) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_event &event_ref = require_event(state, event);
    qd_stream &stream_ref = require_stream(state, stream);
    BlockingSection blocking;
    state.program->stream_manager().record_event(event_ref.event_handle, stream_ref.stream_handle);
  });
}

HL_PRIM void HL_NAME(stream_event_sync)(qd_context *ctx, qd_event *event) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_event &event_ref = require_event(state, event);
    BlockingSection blocking;
    state.program->stream_manager().synchronize_event(event_ref.event_handle);
  });
}

HL_PRIM void HL_NAME(stream_wait_event)(qd_context *ctx, qd_stream *stream, qd_event *event) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_stream &stream_ref = require_stream(state, stream);
    qd_event &event_ref = require_event(state, event);
    BlockingSection blocking;
    state.program->stream_manager().stream_wait_event(stream_ref.stream_handle, event_ref.event_handle);
  });
}

HL_PRIM void HL_NAME(stream_event_close)(qd_event *event) {
  guard([&]() { release_event_handle(event); });
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
    state.program->set_random_seed(seed);
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

HL_PRIM double HL_NAME(profiler_query_min)(qd_context *ctx, vbyte *kernel_name) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    require_profiler(state);
    auto result = state.program->query_kernel_profile_info(
        kernel_name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(kernel_name)));
    return result.min;
  });
}

HL_PRIM double HL_NAME(profiler_query_max)(qd_context *ctx, vbyte *kernel_name) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    require_profiler(state);
    auto result = state.program->query_kernel_profile_info(
        kernel_name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(kernel_name)));
    return result.max;
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

HL_PRIM int HL_NAME(profiler_is_enabled)(qd_context *ctx) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return profiler_enabled(state) ? 1 : 0;
  });
}

HL_PRIM int HL_NAME(profiler_scoped_available)(qd_context *ctx) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return profiler_enabled(state) ? 1 : 0;
  });
}

HL_PRIM int HL_NAME(profiler_memory_available)(qd_context *ctx) {
  return guard([&]() -> int {
    require_context(ctx);
    return 0;
  });
}

HL_PRIM int HL_NAME(profiler_kernel_available)(qd_context *ctx) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return profiler_enabled(state) ? 1 : 0;
  });
}

HL_PRIM int HL_NAME(profiler_set_toolkit)(qd_context *ctx, vbyte *toolkit_name) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return require_profiler(state).set_profiler_toolkit(bytes_to_string(toolkit_name)) ? 1 : 0;
  });
}

HL_PRIM int HL_NAME(profiler_set_metrics)(qd_context *ctx, varray *metric_names) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    std::vector<std::string> metrics = strings_from_hl_array(metric_names, "profiler metric");
    return require_profiler(state).reinit_with_metrics(metrics) ? 1 : 0;
  });
}

HL_PRIM int HL_NAME(sparse_backend_kind)(qd_context *ctx) {
  return guard([&]() -> int {
    require_context(ctx);
    return 0;
  });
}

HL_PRIM int HL_NAME(sparse_supports_native_backend)(qd_context *ctx) {
  return guard([&]() -> int {
    require_context(ctx);
    return 0;
  });
}

HL_PRIM int HL_NAME(sparse_supports_dtype)(qd_context *ctx, int dtype) {
  return guard([&]() -> int {
    require_context(ctx);
    return sparse_supported_dtype(primitive_id_from_bridge_id(dtype)) ? 1 : 0;
  });
}

HL_PRIM qd_sparse_matrix *HL_NAME(sparse_matrix_create)(qd_context *ctx, int rows, int cols, int dtype, int storage_format) {
  return guard([&]() -> qd_sparse_matrix * {
    if (rows <= 0 || cols <= 0) {
      throw std::runtime_error("Quadrants sparse matrix dimensions must be positive");
    }
    PrimitiveTypeID primitive = primitive_id_from_bridge_id(dtype);
    require_sparse_supported_dtype(primitive);
    require_sparse_storage_format(storage_format);
    QdContextState &state = require_context(ctx);
    return make_sparse_matrix_handle(state, rows, cols, primitive, storage_format);
  });
}

HL_PRIM void HL_NAME(sparse_matrix_close)(qd_sparse_matrix *matrix) {
  guard([&]() { release_sparse_matrix_handle(matrix); });
}

HL_PRIM void HL_NAME(sparse_matrix_clear)(qd_context *ctx, qd_sparse_matrix *matrix) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    require_sparse_matrix(state, matrix).entries.clear();
  });
}

HL_PRIM int HL_NAME(sparse_matrix_rows)(qd_context *ctx, qd_sparse_matrix *matrix) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return require_sparse_matrix(state, matrix).rows;
  });
}

HL_PRIM int HL_NAME(sparse_matrix_cols)(qd_context *ctx, qd_sparse_matrix *matrix) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return require_sparse_matrix(state, matrix).cols;
  });
}

HL_PRIM int HL_NAME(sparse_matrix_nnz)(qd_context *ctx, qd_sparse_matrix *matrix) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    return static_cast<int>(require_sparse_matrix(state, matrix).entries.size());
  });
}

HL_PRIM void HL_NAME(sparse_matrix_set_f32)(qd_context *ctx, qd_sparse_matrix *matrix, int row, int col, double value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f32);
    sparse_set_value(matrix_ref, row, col, value);
  });
}

HL_PRIM double HL_NAME(sparse_matrix_get_f32)(qd_context *ctx, qd_sparse_matrix *matrix, int row, int col) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f32);
    require_sparse_index(matrix_ref, row, col);
    return sparse_get_value(matrix_ref, row, col);
  });
}

HL_PRIM void HL_NAME(sparse_matrix_matvec_f32)(qd_context *ctx, qd_sparse_matrix *matrix, qd_ndarray *x, qd_ndarray *y) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f32);
    std::vector<double> x_values = read_sparse_vector(state, x, PrimitiveTypeID::f32, matrix_ref.cols, "input");
    std::vector<double> y_values = sparse_matvec_host(matrix_ref, x_values);
    write_sparse_vector(state, y, PrimitiveTypeID::f32, y_values, "output");
  });
}

HL_PRIM void HL_NAME(sparse_matrix_set_f64)(qd_context *ctx, qd_sparse_matrix *matrix, int row, int col, double value) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f64);
    sparse_set_value(matrix_ref, row, col, value);
  });
}

HL_PRIM double HL_NAME(sparse_matrix_get_f64)(qd_context *ctx, qd_sparse_matrix *matrix, int row, int col) {
  return guard([&]() -> double {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f64);
    require_sparse_index(matrix_ref, row, col);
    return sparse_get_value(matrix_ref, row, col);
  });
}

HL_PRIM void HL_NAME(sparse_matrix_matvec_f64)(qd_context *ctx, qd_sparse_matrix *matrix, qd_ndarray *x, qd_ndarray *y) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f64);
    std::vector<double> x_values = read_sparse_vector(state, x, PrimitiveTypeID::f64, matrix_ref.cols, "input");
    std::vector<double> y_values = sparse_matvec_host(matrix_ref, x_values);
    write_sparse_vector(state, y, PrimitiveTypeID::f64, y_values, "output");
  });
}

HL_PRIM qd_sparse_solver *HL_NAME(sparse_solver_create)(qd_context *ctx,
                                                        int dtype,
                                                        vbyte *solver_type,
                                                        vbyte *ordering,
                                                        int allow_host_dense_fallback) {
  return guard([&]() -> qd_sparse_solver * {
    PrimitiveTypeID primitive = primitive_id_from_bridge_id(dtype);
    require_sparse_supported_dtype(primitive);
    QdContextState &state = require_context(ctx);
    std::string solver = solver_type == nullptr ? std::string("LU") : std::string(reinterpret_cast<const char *>(solver_type));
    std::string order = ordering == nullptr ? std::string("COLAMD") : std::string(reinterpret_cast<const char *>(ordering));
    require_supported_sparse_solver_options(solver, order);
    return make_sparse_solver_handle(state, primitive, std::move(solver), std::move(order), allow_host_dense_fallback != 0);
  });
}

HL_PRIM void HL_NAME(sparse_solver_close)(qd_sparse_solver *solver) {
  guard([&]() { release_sparse_solver_handle(solver); });
}

HL_PRIM int HL_NAME(sparse_solver_compute)(qd_context *ctx, qd_sparse_solver *solver, qd_sparse_matrix *matrix) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    qd_sparse_solver &solver_ref = require_sparse_solver(state, solver);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_supported_dtype(matrix_ref.dtype);
    if (solver_ref.dtype != matrix_ref.dtype) {
      throw std::runtime_error("Quadrants sparse solver dtype mismatch");
    }
    require_host_dense_fallback_enabled(solver_ref);
    if (matrix_ref.rows != matrix_ref.cols) {
      solver_ref.computed = true;
      solver_ref.last_info = false;
      return 0;
    }
    std::vector<double> dense = dense_from_sparse(matrix_ref);
    std::vector<double> rhs(static_cast<std::size_t>(matrix_ref.rows), 0.0);
    std::vector<double> solution;
    solver_ref.last_info = solve_dense_system(std::move(dense), std::move(rhs), matrix_ref.rows, solution);
    solver_ref.computed = true;
    return solver_ref.last_info ? 1 : 0;
  });
}

HL_PRIM int HL_NAME(sparse_solver_info)(qd_context *ctx, qd_sparse_solver *solver) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    qd_sparse_solver &solver_ref = require_sparse_solver(state, solver);
    return solver_ref.last_info ? 1 : 0;
  });
}

void sparse_solver_solve_host(QdContextState &state,
                              qd_sparse_solver &solver_ref,
                              qd_sparse_matrix &matrix_ref,
                              qd_ndarray *b,
                              qd_ndarray *x) {
  require_sparse_supported_dtype(matrix_ref.dtype);
  if (solver_ref.dtype != matrix_ref.dtype) {
    throw std::runtime_error("Quadrants sparse solver dtype mismatch");
  }
  require_host_dense_fallback_enabled(solver_ref);
  if (matrix_ref.rows != matrix_ref.cols) {
    throw std::runtime_error("Quadrants sparse solver requires a square matrix");
  }
  std::vector<double> rhs = read_sparse_vector(state, b, matrix_ref.dtype, matrix_ref.rows, "rhs");
  std::vector<double> solution;
  solver_ref.last_info = solve_dense_system(dense_from_sparse(matrix_ref), std::move(rhs), matrix_ref.rows, solution);
  solver_ref.computed = true;
  if (!solver_ref.last_info) {
    throw std::runtime_error("Quadrants sparse solver failed to factorize matrix");
  }
  write_sparse_vector(state, x, matrix_ref.dtype, solution, "solution");
}

HL_PRIM void HL_NAME(sparse_solver_solve_f32)(qd_context *ctx,
                                             qd_sparse_solver *solver,
                                             qd_sparse_matrix *matrix,
                                             qd_ndarray *b,
                                             qd_ndarray *x) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_sparse_solver &solver_ref = require_sparse_solver(state, solver);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f32);
    sparse_solver_solve_host(state, solver_ref, matrix_ref, b, x);
  });
}

HL_PRIM void HL_NAME(sparse_solver_solve_f64)(qd_context *ctx,
                                             qd_sparse_solver *solver,
                                             qd_sparse_matrix *matrix,
                                             qd_ndarray *b,
                                             qd_ndarray *x) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    qd_sparse_solver &solver_ref = require_sparse_solver(state, solver);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f64);
    sparse_solver_solve_host(state, solver_ref, matrix_ref, b, x);
  });
}

HL_PRIM int HL_NAME(sparse_cg_solve_f32)(qd_context *ctx,
                                        qd_sparse_matrix *matrix,
                                        qd_ndarray *b,
                                        qd_ndarray *x,
                                        int max_iterations,
                                        double tolerance) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f32);
    return sparse_cg_solve_host(state, matrix_ref, b, x, max_iterations, tolerance);
  });
}

HL_PRIM int HL_NAME(sparse_cg_solve_f64)(qd_context *ctx,
                                        qd_sparse_matrix *matrix,
                                        qd_ndarray *b,
                                        qd_ndarray *x,
                                        int max_iterations,
                                        double tolerance) {
  return guard([&]() -> int {
    QdContextState &state = require_context(ctx);
    qd_sparse_matrix &matrix_ref = require_sparse_matrix(state, matrix);
    require_sparse_dtype(matrix_ref, PrimitiveTypeID::f64);
    return sparse_cg_solve_host(state, matrix_ref, b, x, max_iterations, tolerance);
  });
}

HL_PRIM qd_ndarray *HL_NAME(ndarray_create)(qd_context *ctx, int dtype, varray *shape) {
  return guard([&]() -> qd_ndarray * {
    QdContextState &state = require_context(ctx);
    std::vector<int> dims = shape_from_hl_array(shape);
    Ndarray *array = state.program->create_ndarray(dtype_from_bridge_id(dtype), dims);
    return make_ndarray_handle(state, array, true);
  });
}

HL_PRIM qd_ndarray *HL_NAME(ndarray_import_dlpack)(qd_context *ctx, int dtype, int64 handle) {
  return guard([&]() -> qd_ndarray * {
    QdContextState &state = require_context(ctx);
    DLManagedTensor *managed = checked_dlpack_handle(handle);
    try {
      require_dlpack_device_matches_context(managed, state.arch);
      const int actual_dtype = bridge_dtype_from_dlpack(managed->dl_tensor.dtype);
      if (actual_dtype != dtype) {
        throw std::runtime_error("Quadrants DLPack dtype mismatch");
      }
      auto shape = dlpack_shape_to_ints(managed);
      require_contiguous_dlpack(managed, shape);
      auto &device = require_llvm_device(state, "DLPack import");
      auto imported = device.import_memory(checked_external_data_ptr(managed), checked_import_byte_size(shape, dtype));
      auto *array = new Ndarray(imported, dtype_from_bridge_id(dtype), shape, ExternalArrayLayout::kNull, DebugInfo(), state.program.get());
      return make_ndarray_handle(state, array, false, managed);
    } catch (...) {
      if (managed->deleter != nullptr) {
        managed->deleter(managed);
      }
      throw;
    }
  });
}

HL_PRIM qd_ndarray *HL_NAME(ndarray_import_external_pointer)(qd_context *ctx, int64 pointer, int dtype, varray *shape) {
  return guard([&]() -> qd_ndarray * {
    QdContextState &state = require_context(ctx);
    if (pointer == 0) {
      throw std::runtime_error("Quadrants external pointer import pointer is null");
    }
    auto dims = shape_from_hl_array(shape);
    auto &device = require_llvm_device(state, "external pointer import");
    auto imported = device.import_memory(reinterpret_cast<void *>(static_cast<intptr_t>(pointer)), checked_import_byte_size(dims, dtype));
    auto *array = new Ndarray(imported, dtype_from_bridge_id(dtype), dims, ExternalArrayLayout::kNull, DebugInfo(), state.program.get());
    return make_ndarray_handle(state, array, false);
  });
}

HL_PRIM int HL_NAME(cuda_gl_interop_available)(qd_context *ctx) {
  return guard([&]() -> int {
#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
    QdContextState &state = require_context(ctx);
    if (!quadrants::arch_is_cuda(state.arch)) {
      return 0;
    }
    quadrants::lang::CUDAContext::get_instance().make_current();
    int count = 0;
    const cudaError_t err = cudaGetDeviceCount(&count);
    return err == cudaSuccess && count > 0 ? 1 : 0;
#else
    (void)ctx;
    return 0;
#endif
  });
}

HL_PRIM qd_cuda_gl_resource *HL_NAME(cuda_gl_register_buffer)(qd_context *ctx, vdynamic *buffer, int byte_size) {
  return guard([&]() -> qd_cuda_gl_resource * {
    QdContextState &state = require_context(ctx);
    if (byte_size <= 0) {
      throw std::runtime_error("Quadrants CUDA/GL registration byte size must be positive");
    }
    require_cuda_gl_interop_context(state);
#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
    const unsigned int gl_buffer = checked_gl_buffer_id(buffer);
    auto *handle = static_cast<qd_cuda_gl_resource *>(hl_gc_alloc_finalizer(sizeof(qd_cuda_gl_resource)));
    new (handle) qd_cuda_gl_resource();
    handle->finalize = finalize_cuda_gl_resource;
    handle->gl_buffer = gl_buffer;
    handle->byte_size = byte_size;
    cudaGraphicsResource *cuda_resource = nullptr;
    check_cuda_gl(cudaGraphicsGLRegisterBuffer(&cuda_resource, gl_buffer, cudaGraphicsRegisterFlagsWriteDiscard), "cudaGraphicsGLRegisterBuffer");
    handle->state = &state;
    handle->resource = cuda_resource;
    retain_state(&state);
    return handle;
#else
    (void)buffer;
    throw std::runtime_error("Quadrants CUDA/GL interop was not built with CUDA toolkit support");
#endif
  });
}

HL_PRIM int64 HL_NAME(cuda_gl_map)(qd_context *ctx, qd_cuda_gl_resource *resource) {
  return guard([&]() -> int64 {
    QdContextState &state = require_context(ctx);
    require_cuda_gl_interop_context(state);
#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
    if (resource == nullptr || resource->state != &state) {
      throw std::runtime_error("Quadrants CUDA/GL resource belongs to a different context");
    }
    cudaGraphicsResource *cuda_resource = checked_cuda_gl_resource(resource);
    bool mapped_here = false;
    if (!resource->mapped) {
      check_cuda_gl(cudaGraphicsMapResources(1, &cuda_resource, 0), "cudaGraphicsMapResources");
      resource->mapped = true;
      mapped_here = true;
    }
    try {
      void *ptr = nullptr;
      std::size_t size = 0;
      check_cuda_gl(cudaGraphicsResourceGetMappedPointer(&ptr, &size, cuda_resource), "cudaGraphicsResourceGetMappedPointer");
      if (ptr == nullptr || size < static_cast<std::size_t>(resource->byte_size)) {
        throw std::runtime_error("Quadrants mapped CUDA/GL pointer is null or smaller than the registered buffer");
      }
      return static_cast<int64>(reinterpret_cast<intptr_t>(ptr));
    } catch (...) {
      if (mapped_here && cudaGraphicsUnmapResources(1, &cuda_resource, 0) == cudaSuccess) {
        resource->mapped = false;
      }
      throw;
    }
#else
    (void)resource;
    throw std::runtime_error("Quadrants CUDA/GL interop was not built with CUDA toolkit support");
#endif
  });
}

HL_PRIM void HL_NAME(cuda_gl_unmap)(qd_context *ctx, qd_cuda_gl_resource *resource) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    require_cuda_gl_interop_context(state);
#if defined(QD_HASHLINK_CUDA_GL_INTEROP)
    if (resource == nullptr || resource->state != &state) {
      throw std::runtime_error("Quadrants CUDA/GL resource belongs to a different context");
    }
    cudaGraphicsResource *cuda_resource = checked_cuda_gl_resource(resource);
    if (resource->mapped) {
      check_cuda_gl(cudaGraphicsUnmapResources(1, &cuda_resource, 0), "cudaGraphicsUnmapResources");
      resource->mapped = false;
    }
#else
    (void)resource;
    throw std::runtime_error("Quadrants CUDA/GL interop was not built with CUDA toolkit support");
#endif
  });
}

HL_PRIM void HL_NAME(cuda_gl_unregister)(qd_cuda_gl_resource *resource) {
  guard([&]() { release_cuda_gl_resource_handle(resource); });
}

HL_PRIM void HL_NAME(ndarray_close)(qd_ndarray *arr) {
  guard([&]() { release_ndarray_handle(arr); });
}
HL_PRIM void HL_NAME(ndarray_clear_autodiff_handles)(qd_ndarray *arr) {
  guard([&]() {
    qd_ndarray &array = require_ndarray_handle(arr, "tensor");
    array.grad_handle = nullptr;
    array.dual_handle = nullptr;
  });
}

HL_PRIM void HL_NAME(ndarray_set_grad_handle)(qd_ndarray *arr, qd_ndarray *grad) {
  guard([&]() {
    qd_ndarray &array = require_ndarray_handle(arr, "tensor");
    qd_ndarray &grad_array = require_ndarray_handle(grad, "tensor grad");
    if (grad_array.state != array.state) {
      throw std::runtime_error("Quadrants tensor grad handle belongs to a different context");
    }
    array.grad_handle = &grad_array;
  });
}

HL_PRIM void HL_NAME(ndarray_set_dual_handle)(qd_ndarray *arr, qd_ndarray *dual) {
  guard([&]() {
    qd_ndarray &array = require_ndarray_handle(arr, "tensor");
    qd_ndarray &dual_array = require_ndarray_handle(dual, "tensor dual");
    if (dual_array.state != array.state) {
      throw std::runtime_error("Quadrants tensor dual handle belongs to a different context");
    }
    array.dual_handle = &dual_array;
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

HL_PRIM int HL_NAME(ndarray_supports_external_pointer_import)(qd_context *ctx) {
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
    if (managed->dl_tensor.strides == nullptr) {
      int64 stride = 1;
      for (int current = managed->dl_tensor.ndim - 1; current > axis; --current) {
        stride *= managed->dl_tensor.shape[current];
      }
      return stride;
    }
    return static_cast<int64>(managed->dl_tensor.strides[axis]);
  });
}

HL_PRIM int64 HL_NAME(dlpack_data_pointer)(int64 handle) {
  return guard([&]() -> int64 {
    return static_cast<int64>(reinterpret_cast<intptr_t>(checked_external_data_ptr(checked_dlpack_handle(handle))));
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

HL_PRIM int HL_NAME(snode_tree_place_quant)(qd_snode_tree *tree,
                                            int parent_snode_id,
                                            int compute_dtype,
                                            int quant_kind,
                                            int bits,
                                            int is_signed,
                                            int fractional_bits,
                                            double scale,
                                            vbyte *name) {
  return guard([&]() -> int {
    qd_snode_tree &tree_ref = require_snode_tree(tree);
    SNode &parent = require_pending_snode(tree_ref, parent_snode_id);
    if (parent.type != SNodeType::quant_array) {
      throw std::runtime_error("Quadrants quant placement requires a quant_array SNode parent");
    }
    QdContextState &state = *tree_ref.state;
    const std::string field_name = name == nullptr ? std::string() : std::string(reinterpret_cast<const char *>(name));
    Type *quant_type = quant_type_from_bridge(quant_kind, bits, is_signed, compute_dtype, fractional_bits, scale);
    Expr field = Expr::make<FieldExpression>(quant_type, state.program->get_next_global_id(field_name));
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
HL_PRIM void HL_NAME(snode_fill_i8)(qd_context *ctx, int snode_id, int value) {
  guard([&]() { fill_snode_int(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_fill_i16)(qd_context *ctx, int snode_id, int value) {
  guard([&]() { fill_snode_int(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_fill_i32)(qd_context *ctx, int snode_id, int value) {
  guard([&]() { fill_snode_int(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_fill_i64)(qd_context *ctx, int snode_id, int64 value) {
  guard([&]() { fill_snode_int(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_fill_u8)(qd_context *ctx, int snode_id, int value) {
  guard([&]() { fill_snode_uint(require_context(ctx), snode_id, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM void HL_NAME(snode_fill_u16)(qd_context *ctx, int snode_id, int value) {
  guard([&]() { fill_snode_uint(require_context(ctx), snode_id, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM void HL_NAME(snode_fill_u32)(qd_context *ctx, int snode_id, int64 value) {
  guard([&]() { fill_snode_uint(require_context(ctx), snode_id, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM void HL_NAME(snode_fill_u64)(qd_context *ctx, int snode_id, int64 value) {
  guard([&]() { fill_snode_uint(require_context(ctx), snode_id, static_cast<quadrants::uint64>(value)); });
}

HL_PRIM void HL_NAME(snode_fill_u1)(qd_context *ctx, int snode_id, int value) {
  guard([&]() { fill_snode_int(require_context(ctx), snode_id, value != 0 ? 1 : 0); });
}

HL_PRIM void HL_NAME(snode_fill_f16)(qd_context *ctx, int snode_id, double value) {
  guard([&]() { fill_snode_float(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_fill_f32)(qd_context *ctx, int snode_id, double value) {
  guard([&]() { fill_snode_float(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_fill_f64)(qd_context *ctx, int snode_id, double value) {
  guard([&]() { fill_snode_float(require_context(ctx), snode_id, value); });
}

HL_PRIM void HL_NAME(snode_copy_to_ndarray)(qd_context *ctx, int snode_id, int dtype, qd_ndarray *arr) {
  guard([&]() { copy_snode_to_ndarray(require_context(ctx), snode_id, primitive_id_from_bridge_id(dtype), arr); });
}

HL_PRIM void HL_NAME(snode_copy_from_ndarray)(qd_context *ctx, int snode_id, int dtype, qd_ndarray *arr) {
  guard([&]() { copy_ndarray_to_snode(require_context(ctx), snode_id, primitive_id_from_bridge_id(dtype), arr); });
}

HL_PRIM void HL_NAME(snode_register_adjoint)(qd_context *ctx, int primal_snode_id, int adjoint_snode_id) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    register_field_peer(state, primal_snode_id, adjoint_snode_id, state.field_adjoint_snodes, "adjoint");
  });
}

HL_PRIM void HL_NAME(snode_register_dual)(qd_context *ctx, int primal_snode_id, int dual_snode_id) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    register_field_peer(state, primal_snode_id, dual_snode_id, state.field_dual_snodes, "dual");
  });
}


HL_PRIM qd_kernel *HL_NAME(kernel_compile)(qd_context *ctx, vbyte *descriptor_bytes, int descriptor_length, int autodiff_mode) {
  return guard([&]() -> qd_kernel * {
    QdContextState &state = require_context(ctx);
    if (descriptor_length < 0) {
      throw std::runtime_error("HashLink kernel descriptor length is negative");
    }
    quadrants::hashlink::KernelDescriptor descriptor = quadrants::hashlink::decode_descriptor(
        reinterpret_cast<const std::uint8_t *>(descriptor_bytes), static_cast<std::size_t>(descriptor_length));
    const AutodiffMode mode = quadrants::hashlink::autodiff_mode_from_bridge_id(autodiff_mode);
    const bool has_field_params = has_field_parameters(descriptor.parameters);
    quadrants::hashlink::KernelBuildResult result;
    if (!has_field_params) {
      BlockingSection blocking;
      result = quadrants::hashlink::build_kernel_from_descriptor(*state.program, descriptor, mode);
    }

    auto metadata = std::make_unique<qd_kernel_metadata>();
    metadata->parameters = descriptor.parameters;
    metadata->return_dtypes = descriptor.return_dtypes;
    metadata->autodiff_mode = mode;
    const bool has_return = descriptor.has_return;
    if (has_field_params) {
      metadata->descriptor = std::make_unique<quadrants::hashlink::KernelDescriptor>(std::move(descriptor));
    }

    auto *handle = static_cast<qd_kernel *>(hl_gc_alloc_finalizer(sizeof(qd_kernel)));
    new (handle) qd_kernel();
    handle->finalize = finalize_kernel;
    handle->state = &state;
    handle->kernel = result.kernel;
    handle->compiled_kernel_data = result.compiled_kernel_data;
    handle->metadata = metadata.release();
    handle->has_return = has_return;
    retain_state(&state);
    return handle;
  });
}

HL_PRIM void HL_NAME(kernel_launch)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    ResolvedKernel resolved = resolve_kernel_for_launch(state, kernel, args);
    LaunchContextBuilder launch_context = resolved.kernel->make_launch_context();
    set_kernel_launch_args(state, kernel, args, *resolved.kernel, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*resolved.compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_launch_graph)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    ResolvedKernel resolved = resolve_kernel_for_launch(state, kernel, args);
    LaunchContextBuilder launch_context = resolved.kernel->make_launch_context();
    launch_context.use_graph = true;
    set_kernel_launch_args(state, kernel, args, *resolved.kernel, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*resolved.compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_launch_graph_do_while)(qd_context *ctx, qd_kernel *kernel, int control_arg_id, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    ResolvedKernel resolved = resolve_kernel_for_launch(state, kernel, args);
    LaunchContextBuilder launch_context = resolved.kernel->make_launch_context();
    configure_graph_do_while(kernel, control_arg_id, launch_context);
    set_kernel_launch_args(state, kernel, args, *resolved.kernel, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*resolved.compiled_kernel_data, launch_context);
  });
}

HL_PRIM void HL_NAME(kernel_launch_on)(qd_context *ctx, qd_kernel *kernel, qd_stream *stream, varray *args) {
  guard([&]() {
    QdContextState &state = require_context(ctx);
    ResolvedKernel resolved = resolve_kernel_for_launch(state, kernel, args);
    qd_stream &stream_ref = require_stream(state, stream);
    LaunchContextBuilder launch_context = resolved.kernel->make_launch_context();
    set_kernel_launch_args(state, kernel, args, *resolved.kernel, launch_context);

    BlockingSection blocking;
    CurrentStreamScope current_stream(*state.program, stream_ref.stream_handle);
    state.program->launch_kernel(*resolved.compiled_kernel_data, launch_context);
  });
}

HL_PRIM vdynamic *HL_NAME(kernel_launch_ret)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  return guard([&]() -> vdynamic * {
    QdContextState &state = require_context(ctx);
    ResolvedKernel resolved = resolve_kernel_for_launch(state, kernel, args);
    if (!kernel->has_return) {
      throw std::runtime_error("Quadrants kernel has no return value");
    }
    const auto &return_dtypes = kernel->metadata->return_dtypes;
    if (return_dtypes.size() != 1) {
      throw std::runtime_error("Quadrants kernel returns multiple values; use launchRets");
    }
    LaunchContextBuilder launch_context = resolved.kernel->make_launch_context();
    set_kernel_launch_args(state, kernel, args, *resolved.kernel, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*resolved.compiled_kernel_data, launch_context);
    state.program->synchronize_and_assert();
    return make_dynamic_return(launch_context, return_dtypes.front(), 0);
  });
}

HL_PRIM varray *HL_NAME(kernel_launch_rets)(qd_context *ctx, qd_kernel *kernel, varray *args) {
  return guard([&]() -> varray * {
    QdContextState &state = require_context(ctx);
    ResolvedKernel resolved = resolve_kernel_for_launch(state, kernel, args);
    if (!kernel->has_return) {
      throw std::runtime_error("Quadrants kernel has no return value");
    }
    LaunchContextBuilder launch_context = resolved.kernel->make_launch_context();
    set_kernel_launch_args(state, kernel, args, *resolved.kernel, launch_context);

    BlockingSection blocking;
    state.program->launch_kernel(*resolved.compiled_kernel_data, launch_context);
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
DEFINE_PRIM(_I32, stream_supports_events, _QD_CONTEXT);
DEFINE_PRIM(_QD_EVENT, stream_event_create, _QD_CONTEXT);
DEFINE_PRIM(_VOID, stream_event_record, _QD_CONTEXT _QD_EVENT _QD_STREAM);
DEFINE_PRIM(_VOID, stream_event_sync, _QD_CONTEXT _QD_EVENT);
DEFINE_PRIM(_VOID, stream_wait_event, _QD_CONTEXT _QD_STREAM _QD_EVENT);
DEFINE_PRIM(_VOID, stream_event_close, _QD_EVENT);
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
DEFINE_PRIM(_F64, profiler_query_min, _QD_CONTEXT _BYTES);
DEFINE_PRIM(_F64, profiler_query_max, _QD_CONTEXT _BYTES);
DEFINE_PRIM(_F64, profiler_query_avg, _QD_CONTEXT _BYTES);
DEFINE_PRIM(_I32, profiler_is_enabled, _QD_CONTEXT);
DEFINE_PRIM(_I32, profiler_scoped_available, _QD_CONTEXT);
DEFINE_PRIM(_I32, profiler_memory_available, _QD_CONTEXT);
DEFINE_PRIM(_I32, profiler_kernel_available, _QD_CONTEXT);
DEFINE_PRIM(_I32, profiler_set_toolkit, _QD_CONTEXT _BYTES);
DEFINE_PRIM(_I32, profiler_set_metrics, _QD_CONTEXT _ARR);

DEFINE_PRIM(_I32, sparse_backend_kind, _QD_CONTEXT);
DEFINE_PRIM(_I32, sparse_supports_native_backend, _QD_CONTEXT);
DEFINE_PRIM(_I32, sparse_supports_dtype, _QD_CONTEXT _I32);
DEFINE_PRIM(_QD_SPARSE_MATRIX, sparse_matrix_create, _QD_CONTEXT _I32 _I32 _I32 _I32);
DEFINE_PRIM(_VOID, sparse_matrix_close, _QD_SPARSE_MATRIX);
DEFINE_PRIM(_VOID, sparse_matrix_clear, _QD_CONTEXT _QD_SPARSE_MATRIX);
DEFINE_PRIM(_I32, sparse_matrix_rows, _QD_CONTEXT _QD_SPARSE_MATRIX);
DEFINE_PRIM(_I32, sparse_matrix_cols, _QD_CONTEXT _QD_SPARSE_MATRIX);
DEFINE_PRIM(_I32, sparse_matrix_nnz, _QD_CONTEXT _QD_SPARSE_MATRIX);
DEFINE_PRIM(_VOID, sparse_matrix_set_f32, _QD_CONTEXT _QD_SPARSE_MATRIX _I32 _I32 _F64);
DEFINE_PRIM(_F64, sparse_matrix_get_f32, _QD_CONTEXT _QD_SPARSE_MATRIX _I32 _I32);
DEFINE_PRIM(_VOID, sparse_matrix_matvec_f32, _QD_CONTEXT _QD_SPARSE_MATRIX _QD_NDARRAY _QD_NDARRAY);
DEFINE_PRIM(_VOID, sparse_matrix_set_f64, _QD_CONTEXT _QD_SPARSE_MATRIX _I32 _I32 _F64);
DEFINE_PRIM(_F64, sparse_matrix_get_f64, _QD_CONTEXT _QD_SPARSE_MATRIX _I32 _I32);
DEFINE_PRIM(_VOID, sparse_matrix_matvec_f64, _QD_CONTEXT _QD_SPARSE_MATRIX _QD_NDARRAY _QD_NDARRAY);
DEFINE_PRIM(_QD_SPARSE_SOLVER, sparse_solver_create, _QD_CONTEXT _I32 _BYTES _BYTES _I32);
DEFINE_PRIM(_VOID, sparse_solver_close, _QD_SPARSE_SOLVER);
DEFINE_PRIM(_I32, sparse_solver_compute, _QD_CONTEXT _QD_SPARSE_SOLVER _QD_SPARSE_MATRIX);
DEFINE_PRIM(_I32, sparse_solver_info, _QD_CONTEXT _QD_SPARSE_SOLVER);
DEFINE_PRIM(_VOID, sparse_solver_solve_f32, _QD_CONTEXT _QD_SPARSE_SOLVER _QD_SPARSE_MATRIX _QD_NDARRAY _QD_NDARRAY);
DEFINE_PRIM(_VOID, sparse_solver_solve_f64, _QD_CONTEXT _QD_SPARSE_SOLVER _QD_SPARSE_MATRIX _QD_NDARRAY _QD_NDARRAY);
DEFINE_PRIM(_I32, sparse_cg_solve_f32, _QD_CONTEXT _QD_SPARSE_MATRIX _QD_NDARRAY _QD_NDARRAY _I32 _F64);
DEFINE_PRIM(_I32, sparse_cg_solve_f64, _QD_CONTEXT _QD_SPARSE_MATRIX _QD_NDARRAY _QD_NDARRAY _I32 _F64);

DEFINE_PRIM(_QD_NDARRAY, ndarray_create, _QD_CONTEXT _I32 _ARR);
DEFINE_PRIM(_QD_NDARRAY, ndarray_import_dlpack, _QD_CONTEXT _I32 _I64);
DEFINE_PRIM(_QD_NDARRAY, ndarray_import_external_pointer, _QD_CONTEXT _I64 _I32 _ARR);
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
DEFINE_PRIM(_VOID, ndarray_clear_autodiff_handles, _QD_NDARRAY);
DEFINE_PRIM(_VOID, ndarray_set_grad_handle, _QD_NDARRAY _QD_NDARRAY);
DEFINE_PRIM(_VOID, ndarray_set_dual_handle, _QD_NDARRAY _QD_NDARRAY);
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
DEFINE_PRIM(_I32, ndarray_supports_external_pointer_import, _QD_CONTEXT);
DEFINE_PRIM(_I64, ndarray_export_device_pointer, _QD_CONTEXT _QD_NDARRAY);
DEFINE_PRIM(_I64, ndarray_export_dlpack, _QD_CONTEXT _QD_NDARRAY);
DEFINE_PRIM(_I32, cuda_gl_interop_available, _QD_CONTEXT);
DEFINE_PRIM(_QD_CUDA_GL_RESOURCE, cuda_gl_register_buffer, _QD_CONTEXT _DYN _I32);
DEFINE_PRIM(_I64, cuda_gl_map, _QD_CONTEXT _QD_CUDA_GL_RESOURCE);
DEFINE_PRIM(_VOID, cuda_gl_unmap, _QD_CONTEXT _QD_CUDA_GL_RESOURCE);
DEFINE_PRIM(_VOID, cuda_gl_unregister, _QD_CUDA_GL_RESOURCE);
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
DEFINE_PRIM(_I32, snode_tree_place_quant, _QD_SNODE_TREE _I32 _I32 _I32 _I32 _I32 _I32 _F64 _BYTES);
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
DEFINE_PRIM(_VOID, snode_fill_i8, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_fill_i16, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_fill_i32, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_fill_i64, _QD_CONTEXT _I32 _I64);
DEFINE_PRIM(_VOID, snode_fill_u8, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_fill_u16, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_fill_u32, _QD_CONTEXT _I32 _I64);
DEFINE_PRIM(_VOID, snode_fill_u64, _QD_CONTEXT _I32 _I64);
DEFINE_PRIM(_VOID, snode_fill_u1, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_fill_f16, _QD_CONTEXT _I32 _F64);
DEFINE_PRIM(_VOID, snode_fill_f32, _QD_CONTEXT _I32 _F64);
DEFINE_PRIM(_VOID, snode_fill_f64, _QD_CONTEXT _I32 _F64);
DEFINE_PRIM(_VOID, snode_copy_to_ndarray, _QD_CONTEXT _I32 _I32 _QD_NDARRAY);
DEFINE_PRIM(_VOID, snode_copy_from_ndarray, _QD_CONTEXT _I32 _I32 _QD_NDARRAY);
DEFINE_PRIM(_VOID, snode_register_adjoint, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_VOID, snode_register_dual, _QD_CONTEXT _I32 _I32);
DEFINE_PRIM(_QD_KERNEL, kernel_compile, _QD_CONTEXT _BYTES _I32 _I32);
DEFINE_PRIM(_VOID, kernel_launch, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_launch_on, _QD_CONTEXT _QD_KERNEL _QD_STREAM _ARR);
DEFINE_PRIM(_VOID, kernel_launch_graph, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_launch_graph_do_while, _QD_CONTEXT _QD_KERNEL _I32 _ARR);
DEFINE_PRIM(_DYN, kernel_launch_ret, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_ARR, kernel_launch_rets, _QD_CONTEXT _QD_KERNEL _ARR);
DEFINE_PRIM(_VOID, kernel_close, _QD_KERNEL);
