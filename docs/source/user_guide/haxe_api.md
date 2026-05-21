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
| `new Tensor<I32>(ctx, [n])`, `new Tensor<F32>(ctx, [m, k])` | Allocate a primitive ndarray whose dtype is fixed by the generic type parameter. |
| `Tensor<T>.fill(value)`, `read(i)`, `write(i, value)` | Typed flat host access. `read()` returns `T`; `write()` only accepts `T`. |
| `Tensor<T>.readAt(indices)`, `writeAt(indices, value)` | Typed multi-dimensional host indexing. |
| `Tensor<T>.toArray()` / `fromArray(values)` | Typed host-array transfer. |
| `Tensor<T>.readBytes(...)`, `writeBytes(...)`, `copyToBytes(...)`, `copyFromBytes(...)` | Raw byte transport for contiguous tensor ranges. |
| `Tensor<T>.view(flatStart, length)` / `BufferView<T>` | Checked flat view over a tensor. `BufferView<T>` kernel parameters flatten to tensor handle + start + length. |
| `Tensor<T>.grad`, `dual`, `enableGrad()` | Typed gradient/dual storage helpers. |
| `new Field<T>(ctx, shape)` / `new Field<T>(ctx)` plus `ctx.root...place(field)` / `Field<T>.toTensor()` | Typed SNode-backed field allocation, placement, host access, and tensor conversion. |
| `Tensor<T>.supportsZeroCopy()`, `supportsDLPack()`, `exportDLPack()`, `exportDevicePointer()` | Capability-probed zero-copy export helpers. DLPack exports must be closed by the caller. |
| `Kernel.build(ctx, macro (...) -> { ... })` | Build and JIT-compile a kernel from a Haxe macro arrow function. |
| `Kernel.descriptorBytes(macro (...) -> { ... })` | Return QDHL descriptor bytes for tests/tooling. |
| `Kernel.launch(args...)` | Launch a compiled kernel. `Tensor<T>` and `Field<T>` arguments are passed through the non-generic runtime handle path. |
| `Kernel.launchRet(...)` / `launchRets(...)` | Launch kernels with primitive scalar or fixed tuple returns. |
| `Kernel.grad()`, `forwardGrad()`, `validationKernel()` | Recompile the stored descriptor in reverse, forward, or validation autodiff mode. |
| `Context.stream()`, `Context.profiler()`, `Context.setOfflineCache(...)`, `Context.setDebugDump(...)` | Runtime stream, profiler, cache, and debug configuration helpers. |
| `Vector<T>`, `Matrix<T>`, `SparseMatrix<T>`, `Mesh` | Host-side containers and helpers. |

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

## Zero-copy and DLPack export

Use capability probes before exporting raw interop handles:

```haxe
var t = new Tensor<F32>(ctx, [2, 3]);
if (t.supportsZeroCopy()) {
  var ptr:haxe.Int64 = t.exportDevicePointer();
}
if (t.supportsDLPack()) {
  var dlpack = t.exportDLPack();
  try {
    var ndim = dlpack.ndim();
    var data = dlpack.dataPointer();
  } finally {
    dlpack.close();
  }
}
```

`DLPackTensor` exposes device, dtype, shape, stride, and data-pointer metadata for the exported tensor. Keep the source tensor alive until the consumer is done. External pointer and DLPack import are still guarded by `supportsExternalPointerImport()`, which currently returns `false`.

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

The Haxe/HashLink binding supports primitive typed ndarrays, typed SNode-backed fields and placement, scalar kernel arguments, basic control flow, n-dimensional range loops, static mesh-for over `Mesh.forVertices/forEdges/forFaces/forCells(literalCount)`, inline `@:qdFunc` helpers, struct/vector/matrix kernel locals, math operations, native backend selection, primitive scalar and tuple return values, streams, graph launches, profiler queries, offline-cache toggles, IR/debug-dump configuration, native autodiff kernel build modes, and zero-copy/DLPack export probes.

Not yet exposed through the Haxe API: Python package modules, mesh relation access, NumPy/PyTorch import, GUI/window interop, and Python decorators.

Use [Haxe kernel language](kernel_language.md) for the exact macro-supported syntax and [Haxe/HashLink integration](hashlink.md) for build and packaging details.
