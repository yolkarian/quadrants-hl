# Haxe/HashLink public API

This page is the Haxe/HL replacement for the former Python binding entry points. New user code should import the `quadrants` Haxe package and run through HashLink JIT bytecode (`haxe -hl ...`, then `hl ...`).

## Execution model

1. Haxe compiles host code to a `.hl` bytecode file.
2. `Kernel.build(ctx, macro (...) -> { ... })` runs at Haxe compile time and serializes the kernel body into a descriptor.
3. At run time, HashLink loads `quadrants.hdll` and calls the native Quadrants bridge.
4. The native bridge JIT-compiles kernels for the selected `Arch`, launches them, and synchronizes through `Context.sync()`.

## Core classes

| Haxe API | Purpose |
| --- | --- |
| `new Context(Arch.Cpu)` | Create a Quadrants runtime context for a backend. |
| `Context.sync()` | Wait for all queued work in the context. |
| `Context.close()` | Release the native program/runtime. Close kernels first. |
| `Context.ndarray(dtype, shape)` | Allocate a primitive ndarray with a `DType` and an `Array<Int>` shape. |
| `Context.ndarrayI32([n])`, `ndarrayF32([n])`, ... | Convenience constructors for primitive dtypes. |
| `Tensor<T>.fillI32(value)`, `readI32(i)`, `writeI32(i, value)` | Host-side primitive ndarray helpers. Flat `fill*`, `read*`, and `write*` helpers exist for every primitive dtype. |
| `Tensor<T>.readBytes(out, flatStart, count, outByteOffset)`, `readF32Bytes(...)`, ... | Bulk-read contiguous primitive elements into `hl.Bytes` as raw little-endian bytes. |
| `Tensor<T>.readI32At([i, j])`, `writeI32At([i, j], value)` | Host-side multi-dimensional indexing helpers for common numeric dtypes. |
| `Kernel.build(ctx, macro (...) -> { ... })` | Build and JIT-compile a kernel from a Haxe macro arrow function. |
| `Kernel.launch(args...)` | Launch a compiled kernel. `Tensor` arguments are converted to native ndarray handles. |
| `Kernel.close()` | Release a compiled kernel. |
| `Vector<T>` and `Matrix<T>` | Lightweight host-side containers with simple elementwise helpers. They are not kernel storage objects. |

## Backend and dtype enums

```haxe
import quadrants.Types.Arch;
import quadrants.Types.DType;
```

`Arch` values are `Cpu`, `Cuda`, `Vulkan`, `Metal`, and `Amdgpu`. `Arch.Cpu` maps to the host LLVM backend (`x64` or `arm64`).

`DType` values are `I8`, `I16`, `I32`, `I64`, `U8`, `U16`, `U32`, `U64`, `F32`, and `F64`.

The Haxe aliases in `quadrants.Types` map kernel scalar annotations to descriptor dtypes: `I32` is `Int`, `I64` is `haxe.Int64`, `F32` is `hl.F32`, and `F64` is `Float`. Host-side unsigned 32-bit and 64-bit tensor helpers use `haxe.Int64` values so the bridge can pass the full bit range through HashLink.

## Primitive bulk readback

Use `Tensor<T>.readBytes(out, flatStart, count, outByteOffset = 0)` to copy a contiguous range of primitive ndarray elements into an `hl.Bytes` buffer with one native synchronization and one bulk staging copy. Typed convenience wrappers are available for every primitive dtype: `readI8Bytes`, `readI16Bytes`, `readI32Bytes`, `readI64Bytes`, `readU8Bytes`, `readU16Bytes`, `readU32Bytes`, `readU64Bytes`, `readF32Bytes`, and `readF64Bytes`.

The output bytes are raw little-endian primitive values, so callers must allocate enough space for `outByteOffset + count * sizeof(dtype)` bytes.

```haxe
var positions = ctx.ndarrayF32([particleCount, 3]);
var bytes = new hl.Bytes(particleCount * 3 * 4);
positions.readF32Bytes(bytes, 0, particleCount * 3);
var x0 = bytes.getF32(0);
```

## Python binding migration map

| Former Python binding | Haxe/HL equivalent |
| --- | --- |
| `import quadrants as qd` | `import quadrants.Context; import quadrants.Kernel; import quadrants.Types.Arch;` |
| `qd.init(arch=qd.cpu)` | `var ctx = new Context(Arch.Cpu);` |
| `qd.cpu`, `qd.cuda`, `qd.vulkan`, `qd.metal`, `qd.amdgpu` | `Arch.Cpu`, `Arch.Cuda`, `Arch.Vulkan`, `Arch.Metal`, `Arch.Amdgpu` |
| `qd.ndarray(qd.i32, shape=(n,))` | `ctx.ndarrayI32([n])` or `ctx.ndarray(DType.I32, [n])` |
| `@qd.kernel def f(...): ...` | `var k = Kernel.build(ctx, macro (...) -> { ... });` |
| `f(a, b, n)` | `k.launch(a, b, n);` |
| `qd.sync()` | `ctx.sync();` |
| Python host indexing (`a[i]`, `a.to_numpy()`) | `read*`, `write*`, `read*At`, `write*At` host helpers. Bulk NumPy/Torch interop is not part of the HL binding. |
| Python package build (`setup.py`, wheels) | CMake `-DQD_WITH_HASHLINK=ON` plus `cmake --install --component hashlink`, producing `quadrants.hdll` and haxelib sources. |
| `pytest`/`tests/run_tests.py` | `ctest --test-dir <build>` plus Haxe `.hxml` files under `tests/hashlink/`. |

## Current feature boundary

The Haxe/HashLink binding intentionally starts with a smaller public surface than the deleted Python binding. The supported surface is primitive ndarrays, scalar kernel arguments, basic control flow, math operations, and native backend selection.

Not yet exposed through the Haxe API:

- Python package modules such as `quadrants.ad`, `quadrants.linalg`, `quadrants.sparse`, `quadrants.profiler`, `quadrants.tools`, and `quadrants.interop`.
- Python fields/SNode tree construction APIs.
- NumPy, PyTorch, DLPack, GUI, and Vulkan/Metal window interop helpers.
- Python decorators (`@qd.kernel`, `@qd.func`) and Python AST features.
- Reverse-mode autodiff and sparse linear algebra entry points.

Use [Haxe kernel language](kernel_language.md) for the exact macro-supported syntax and [Haxe/HashLink integration](hashlink.md) for build and packaging details.
