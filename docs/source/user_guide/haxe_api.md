# Haxe/HashLink public API

This page is the Haxe/HL replacement for the former Python binding entry points. New user code should import the `quadrants` Haxe package and run through HashLink JIT bytecode (`haxe -hl ...`, then `hl ...`).

## Execution model

1. Haxe compiles host code to a `.hl` bytecode file.
2. `Kernel.build(ctx, macro (...) -> { ... })` runs at Haxe compile time and serializes the kernel body into a descriptor.
3. At run time, HashLink loads `quadrants.hdll` and calls the native Quadrants bridge.
4. The native bridge JIT-compiles kernels for the selected `Arch`, launches them, and synchronizes through `Context.sync()`.

## Breaking changes: typed Tensor construction

Tensor allocation is now constructor-based and dtype-safe.

Old:

```haxe
var a = ctx.ndarrayI32([n]);
a.writeI32(0, 1);
var x = a.readI32(0);
```

New:

```haxe
var a = new Tensor<I32>(ctx, [n]);
a.write(0, 1);
var x:I32 = a.read(0);
```

Removed APIs:

- `Context.ndarray(dtype, shape)`
- `Context.ndarrayI8/I16/I32/I64`
- `Context.ndarrayU8/U16/U32/U64/U1`
- `Context.ndarrayF16/F32/F64`
- dtype-specific tensor host helpers such as `readI32`, `writeF32`, `fillU1`, `readF64At`, `toArrayI16`, and `fromArrayF32`
- `Context.fieldI32()` and other dtype-specific field helpers

Use `new Field<I32>(ctx, shape)` or `new Field<I32>(ctx)` plus `ctx.root.place(field)` for fields.

## Core classes

| Haxe API | Purpose |
| --- | --- |
| `new Context(Arch.Cpu, enableProfiler = false)` | Create a Quadrants runtime context for a backend. |
| `Context.sync()` / `Context.close()` | Synchronize queued work and release the native context. |
| `Context.supportsStreamEvents()` / `Context.clearOfflineCache()` | Query event support (`Cuda`/`Amdgpu`) and delete a previously configured offline-cache tree. |
| `new Tensor<I32>(ctx, [n])`, `new Tensor<F32>(ctx, [m, k])` | Allocate a primitive ndarray whose dtype is fixed by the generic type parameter. |
| `Tensor<T>.fill(value)`, `read(i)`, `write(i, value)` | Typed flat host access. `read()` returns `T`; `write()` only accepts `T`. |
| `Tensor<T>.readAt(indices)`, `writeAt(indices, value)` | Typed multi-dimensional host indexing. |
| `Tensor<T>.toArray()` / `fromArray(values)` | Typed host-array transfer. |
| `Tensor<T>.readBytes(...)`, `writeBytes(...)`, `copyToBytes(...)`, `copyFromBytes(...)` | Raw byte transport for contiguous tensor ranges. |
| `Tensor<T>.view(flatStart, length)` / `BufferView<T>` | Checked flat view over a tensor. `BufferView<T>` kernel parameters flatten to tensor handle + start + length. |
| `Tensor<T>.grad`, `dual`, `enableGrad()` | Typed gradient/dual storage helpers. |
| `Tensor<T>.fromDLPack(...)`, `importDLPack(...)`, `fromExternalPointer(...)`, `importExternalPointer(...)` | Import typed tensors from contiguous DLPack capsules or external pointers on LLVM-backed backends. |
| `new Field<T>(ctx, shape)` / `new Field<T>(ctx)` plus `ctx.root...place(field)` / `Field<T>.toTensor()` / `Field<T>.fromTensor(...)` | Typed SNode-backed field allocation, placement, host access, tensor conversion, and tensor-to-field copies. |
| `Tensor<T>.supportsZeroCopy()`, `supportsDLPack()`, `supportsExternalPointerImport()`, `exportDLPack()`, `exportDevicePointer()` | Capability-probed interop helpers. DLPack exports must be closed by the caller. |
| `Kernel.build(ctx, macro (...) -> { ... })` / `Template.build(DType.I32, ctx, macro (...:Tensor<TemplateDType>, ...) -> { ... })` | Build and JIT-compile a concrete kernel directly, or specialize one typed kernel template across dtypes. |
| `Kernel.descriptorBytes(...)` / `Template.descriptorBytes(...)` | Return QDHL descriptor bytes for tests/tooling. |
| `Kernel.launch(args...)`, `launchGraph(...)`, `launchGraphWhile(...)`, `launchGraphDoWhile(...)` | Launch a compiled kernel directly or through graph execution helpers. |
| `Kernel.launchRet(...)` / `launchRets(...)` | Launch kernels with primitive scalar or fixed tuple returns. |
| `Kernel.grad()`, `forwardGrad()`, `validationKernel()` | Recompile the stored descriptor in reverse, forward, or validation autodiff mode. |
| `Context.stream()`, `Context.setOfflineCache(...)`, `Context.setDebugDump(...)` | Create execution streams and configure cache / debug-dump behavior for the context. |
| `Stream.createEvent()` / `Stream.recordEvent(...)` / `Stream.waitEvent(...)` / `StreamEvent.sync()` | CUDA/AMDGPU stream-event coordination helpers. |
| `Context.profiler()`, `Profiler.recordKernel(...)`, `Profiler.min/max/avg/count(...)` | Runtime profiler queries by kernel name or kernel instance. |
| `Struct.decodeSchema({field: 0, nested: {value: 0}}, kernel.launchRets(...))` | Decode flattened struct returns back into nested Haxe object literals. |
| `Shared.array(DType.I32, size)` / `Shared.tile16(DType.F32)` | Generic shared-memory factories inside kernel bodies, alongside the dtype-specific `Shared.arrayI32(...)` / `Shared.tile16F32()` forms. |
| `CudaGlInterop.available(ctx)` / `CudaGlInterop.registerBuffer(ctx, glBuffer, byteSize)` | Query CUDA/OpenGL interop availability and register an OpenGL buffer with CUDA. |
| `CudaGlResource.map()` / `unmap()` / `dispose()` / `close()` | Map a registered OpenGL buffer to a CUDA device pointer, unmap after device writes, and unregister on cleanup. |

## Backend and dtype enums

```haxe
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.I32;
import quadrants.Types.F32;
```

`Arch` values are `Cpu`, `Cuda`, `Vulkan`, `Metal`, and `Amdgpu`.

`DType` values are `I8`, `I16`, `I32`, `I64`, `U8`, `U16`, `U32`, `U64`, `F16`, `F32`, `F64`, and `U1`.

The dtype types in `quadrants.Types` are distinct abstracts, so `Tensor<I8>`, `Tensor<I16>`, and `Tensor<I32>` are different Haxe types even though their host representation is integer-like. `U32` and `U64` host values use `haxe.Int64` so the full unsigned range can pass through HashLink. `F32` uses `hl.F32` and accepts `Float` literals for host convenience.

## Primitive bulk byte transfers

Use `Tensor<T>.readBytes(out, flatStart, count, outByteOffset = 0)` and `writeBytes(input, flatStart, count, inputByteOffset = 0)` to copy raw little-endian primitive values. `copyToBytes` and `copyFromBytes` default to the whole tensor. Typed byte wrappers such as `readI32Bytes` and `readF32Bytes` were removed; the tensor dtype is already fixed by `T`.

```haxe
var positions = new Tensor<F32>(ctx, [particleCount, 3]);
var bytes = new hl.Bytes(particleCount * 3 * 4);
positions.readBytes(bytes, 0, particleCount * 3);
var x0 = bytes.getF32(0);
```

## Field placement

`Field<T>` uses the same generic dtype binding as `Tensor<T>`. `new Field<I32>(ctx, [n])` creates a dense placed field, while `new Field<I32>(ctx)` can be placed explicitly through the context root:

```haxe
var flags = new Field<U1>(ctx);
ctx.root.pointer(Axis.i, 8).bitmasked(Axis.i, 4).place(flags);
flags.write(3, true);
var asTensor:Tensor<U1> = flags.toTensor();
```

Host `read`, `write`, `fill`, `toArray`, `fromArray`, `grad`, `dual`, and `toTensor()` remain typed by `T`.

## Interop import/export

Use capability probes before exporting raw interop handles or importing external storage:

```haxe
var t = new Tensor<F32>(ctx, [2, 3]);
if (t.supportsZeroCopy()) {
  var ptr:haxe.Int64 = t.exportDevicePointer();
  var alias = Tensor<F32>.fromExternalPointer(ctx, ptr, [2, 3]);
}
if (t.supportsDLPack()) {
  var dlpack = t.exportDLPack();
  try {
    var ndim = dlpack.ndim();
    var data = dlpack.dataPointer();
    var imported = Tensor<F32>.fromDLPack(ctx, dlpack);
    imported.write(0, 7.0);
  } finally {
    // `fromDLPack` / `importDLPack` consume the handle on success.
    if (dlpack != null) dlpack.close();
  }
}
```

`DLPackTensor` exposes device, dtype, shape, stride, and data-pointer metadata for exported tensors. `Tensor<T>.fromDLPack(...)` and `importDLPack(...)` accept contiguous row-major primitive tensors whose DLPack dtype exactly matches `T`. `Tensor<T>.fromExternalPointer(...)` and `importExternalPointer(...)` wrap an existing device/host pointer with the current context and shape. Exported DLPack tensors and device pointers alias storage owned by the source tensor, so keep the source tensor and context alive until every consumer of that alias is finished.

`supportsExternalPointerImport()` is currently true only for LLVM-backed contexts (`Cpu`, `Cuda`, and `Amdgpu`). Vulkan and Metal still do not expose external-pointer or DLPack-import paths through the HashLink bridge.

## CUDA/OpenGL interop

The `CudaGlInterop` and `CudaGlResource` classes allow a HashLink renderer to share OpenGL buffers with CUDA kernels without a host-side copy. This requires `Arch.Cuda` and a `quadrants.hdll` built with `QD_WITH_CUDA=ON` and the CUDA toolkit found by CMake.

```haxe
import quadrants.Context;
import quadrants.CudaGlInterop;
import quadrants.CudaGlResource;
import quadrants.Types.Arch;

var ctx = new Context(Arch.Cuda);
if (!CudaGlInterop.available(ctx)) {
  throw "CUDA/GL interop is not available on this context";
}

// Register an OpenGL buffer (e.g. hlsdl's sdl.GL.Buffer) with CUDA.
var resource = CudaGlInterop.registerBuffer(ctx, glBuffer, byteSize);

// Map for device writes, write via a Tensor obtained from the pointer, then unmap.
var devicePtr:haxe.Int64 = resource.map();
// ... launch a kernel that writes to devicePtr ...
resource.unmap();

// Release the registration when the OpenGL buffer is no longer needed.
resource.dispose();
```

`CudaGlInterop.available(ctx)` returns `true` only when the native bridge was built with CUDA and the context backend is `Cuda`. On non-CUDA builds it returns `false` and does not throw.

`CudaGlInterop.registerBuffer(ctx, glBuffer, byteSize)` registers an OpenGL buffer object with CUDA. The `glBuffer` parameter is typed `Dynamic` so Quadrants does not depend on hlsdl; hlsdl's `sdl.GL.Buffer` can be passed directly. `byteSize` must be positive.

`CudaGlResource` holds the registration and must stay alive for as long as the mapped device pointer is in use. `map()` returns a `haxe.Int64` CUDA device pointer; `unmap()` releases it after device writes are finished and is safe to call when already unmapped; `dispose()` unregisters the resource and cleans up. `close()` is an alias for `dispose()`. Calling `dispose()` or `close()` on a mapped resource implicitly unmaps it first in the native bridge.

## Python binding migration map

| Former Python binding | Haxe/HL equivalent |
| --- | --- |
| `import quadrants as qd` | `import quadrants.Context; import quadrants.Kernel; import quadrants.Types.Arch;` |
| `qd.init(arch=qd.cpu)` | `var ctx = new Context(Arch.Cpu);` |
| `qd.cpu`, `qd.cuda`, `qd.vulkan`, `qd.metal`, `qd.amdgpu` | `Arch.Cpu`, `Arch.Cuda`, `Arch.Vulkan`, `Arch.Metal`, `Arch.Amdgpu` |
| `qd.ndarray(qd.i32, shape=(n,))` | `new Tensor<I32>(ctx, [n])` |
| `@qd.kernel def f(...): ...` | `var k = Kernel.build(ctx, macro (...) -> { ... });` |
| `f(a, b, n)` | `k.launch(a, b, n);` |
| `qd.sync()` | `ctx.sync();` |
| Python host indexing (`a[i]`, `a.to_numpy()`) | `read`, `write`, `readAt`, `writeAt`, `toArray`, `fromArray`, or raw bytes. |

## Current feature boundary

The Haxe/HashLink binding supports primitive typed ndarrays, typed SNode-backed fields and placement, scalar kernel arguments, basic control flow, n-dimensional range loops, static mesh-for over `Mesh.forVertices/forEdges/forFaces/forCells(literalCount)`, inline `@:qdFunc` helpers, template-specialized kernels via `Template.build(...)`, struct/vector/matrix kernel locals, flattened struct returns decoded with `Struct.decodeSchema(...)`, generic or dtype-specific shared-memory factories, native backend selection, primitive scalar and tuple return values, streams, stream events on CUDA/AMDGPU, graph launches including `launchGraphWhile(...)`, profiler queries, offline-cache toggles and clearing, IR/debug-dump configuration, native autodiff kernel build modes, CUDA/OpenGL interop via `CudaGlInterop` and `CudaGlResource`, and zero-copy / external-pointer / DLPack interop on LLVM-backed backends.

Not yet exposed through the Haxe API: Python package modules, mesh relation access inside kernels, NumPy/PyTorch import, GUI/window interop, and Python decorators.

Use [Haxe kernel language](kernel_language.md) for the exact macro-supported syntax and [Haxe/HashLink integration](hashlink.md) for build and packaging details.
