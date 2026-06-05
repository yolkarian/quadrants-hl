# Quadrants Haxe/HashLink bindings

This directory is a haxelib-compatible package root for the Quadrants HashLink bridge (`quadrants.hdll`). Haxe programs compile to HashLink bytecode (`haxe -hl ...`) and execute through the HashLink JIT (`hl ...`). The canonical CMake install layout is under `share/quadrants/hashlink`.

## Installed layout

```text
share/quadrants/hashlink/haxelib.json
share/quadrants/hashlink/quadrants.hdll
share/quadrants/hashlink/README.md
share/quadrants/hashlink/haxe/quadrants/*.hx
share/quadrants/hashlink/haxe/quadrants/runtime/*.hx
share/quadrants/hashlink/haxe/quadrants/simt/*.hx
share/quadrants/hashlink/haxe/quadrants/algorithms/*.hx
share/quadrants/hashlink/haxe/quadrants/ad/*.hx
share/quadrants/hashlink/haxe/quadrants/coverage/*.hx
share/quadrants/hashlink/haxe/quadrants/compat/*.hx
share/quadrants/hashlink/haxe/quadrants/packed/*.hx
share/quadrants/hashlink/haxe/quadrants/snode/*.hx
share/quadrants/hashlink/haxe/quadrants/linalg/*.hx
share/quadrants/hashlink/haxe/quadrants/profiler/*.hx
share/quadrants/hashlink/haxe/quadrants/macro/*.hx
share/quadrants/hashlink/runtime/runtime_x64.bc        # or runtime_arm64.bc
share/quadrants/hashlink/runtime/runtime_cuda.bc       # CUDA builds
share/quadrants/hashlink/runtime/slim_libdevice.10.bc  # CUDA builds
```

## Backend support

| Haxe arch | Required native build/runtime support |
| --- | --- |
| `Arch.Cpu` | `QD_WITH_LLVM=ON` with LLVM/Clang 22+ and host runtime bitcode (`runtime_x64.bc` or `runtime_arm64.bc`) |
| `Arch.Cuda` | `QD_WITH_CUDA=ON`, CUDA driver libraries, `runtime_cuda.bc`, `slim_libdevice.10.bc` |
| `Arch.Vulkan` | `QD_WITH_VULKAN=ON` and Vulkan loader/driver libraries visible to `hl` |
| `Arch.Metal` | macOS, `QD_WITH_METAL=ON` |
| `Arch.Amdgpu` | Linux x64, `QD_WITH_AMDGPU=ON`, ROCm/HIP libraries and AMDGPU runtime/device bitcode |

## Package and install

A CPU + CUDA haxelib package should contain `quadrants.hdll`, Haxe sources, `runtime_x64.bc` or `runtime_arm64.bc`, `runtime_cuda.bc`, and `slim_libdevice.10.bc`. Configure the CMake build with `QD_WITH_HASHLINK=ON`, `QD_WITH_LLVM=ON`, and `QD_WITH_CUDA=ON` before packaging.

```bash
QD_BUILD_DIR="$PWD/build/hashlink"
cmake --build "$QD_BUILD_DIR" --target quadrants.hdll
scripts/package_hashlink_haxelib.sh \
  --build-dir "$QD_BUILD_DIR" \
  --runtime-dir "$QD_BUILD_DIR/runtime" \
  --out build/quadrants-haxelib.zip
haxelib --global install build/quadrants-haxelib.zip --always
```

The package script validates that the selected `quadrants.hdll` exports the `@:hlNative` functions used by the current Haxe sources and that `runtime/` contains host `runtime_*.bc` bitcode. If the native-symbol check fails, rebuild `quadrants.hdll`; use `--skip-native-symbol-check` only when deliberately packaging against a different Haxe/native pair. Vulkan/Metal-only packages without LLVM bitcode should pass `--allow-no-runtime`.

For development from a CMake install tree, use `haxelib dev` instead:

```bash
QD_INSTALL_DIR="$PWD/build/hashlink-install"
haxelib dev quadrants "$QD_INSTALL_DIR/share/quadrants/hashlink"
```

## Smoke test

```bash
haxe -lib quadrants -cp tests/hashlink -main Smoke -hl build/hashlink-smoke.hl
hl build/hashlink-smoke.hl
```

CUDA smoke tests are opt-in:

```bash
QD_HASHLINK_TEST_ARCHES=cuda \
haxe -lib quadrants -cp tests/hashlink -main Smoke -hl build/hashlink-smoke-cuda.hl
QD_HASHLINK_TEST_ARCHES=cuda \
LD_LIBRARY_PATH="/usr/local/cuda/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}" \
hl build/hashlink-smoke-cuda.hl
```

For a build-tree run without haxelib registration or package install, pass the bridge and runtime paths while compiling the `.hl` bytecode:

```bash
QUADRANTS_HDLL="$QD_BUILD_DIR/quadrants.hdll" \
QUADRANTS_RUNTIME_DIR="$QD_BUILD_DIR/runtime" \
haxe tests/hashlink/hashlink_smoke.hxml -hl build/hashlink-smoke-buildtree.hl
QD_LIB_DIR="$QD_BUILD_DIR/runtime" \
LD_LIBRARY_PATH="$QD_BUILD_DIR:${LD_LIBRARY_PATH:-}" \
hl build/hashlink-smoke-buildtree.hl
```

The same paths can also be passed as Haxe defines: `-D quadrants_hdll_path=/path/to/quadrants.hdll` and `-D quadrants_runtime_dir=/path/to/runtime`.

## Runtime facade

User code can keep the explicit context model:

```haxe
var ctx = new quadrants.Context(Arch.Cpu);
```

For small programs, `quadrants.runtime.Runtime` manages one default `Session`:

```haxe
Runtime.init(Arch.Cpu);
var ctx = Runtime.context();
Runtime.sync();
Runtime.reset();
```

`Runtime.reset()` closes the default session's context. A `Session` returned by an earlier `Runtime.init(...)` is invalid after `reset()` or a later `init(...)`; use explicit `Context` objects when ownership must be independent of the process default.

## Kernel helper libraries

Reusable kernel helper classes can be passed explicitly to `Kernel.build`:

```haxe
var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>, n:I32) -> {
  for (i in 0...n) {
    out[i] = MyKernelHelpers.square(a[i]);
  }
}, {helpers: [MyKernelHelpers]});
```

Helper classes expose `static` methods marked `@:qdFunc`. Helper names must be unique across every listed class and the local class; recursive helper calls are rejected at compile time.

## SIMT helpers and algorithms

`quadrants.simt` provides explicit helper classes for kernels built with helper options:

```haxe
var k = Kernel.build(ctx, macro (input:Tensor<I32>, out:Tensor<I32>) -> {
  blockDim(16);
  var lane = Block.threadIdx();
  var sum = BlockReduce.reduceAddI32Tile16(input[lane]);
  if (lane == 0) out[0] = sum;
}, {helpers: [BlockReduce]});
```

`quadrants.algorithms` adds Haxe-only host orchestration for scalar `I32`/`F32` tensors: reductions, exclusive add/min/max scans, select/compaction, simple sort/radix-sort entrypoints, `PrefixSumExecutor`, reduce-by-key add, and a reusable `Scratch` manager. Public algorithm signatures relate inputs and outputs with `Tensor<T>`, so dtype mismatches and tensor/field mixups fail at Haxe compile time before the remaining runtime dtype support checks run. The current implementations prioritize deterministic correctness and small/medium tensor usability; backend behavior is documented in `docs/source/user_guide/haxe_api.md`.

## Autodiff, coverage, and diagnostics

`Tape.run(...)`, `Tape.runBackward(...)`, `Tape.runForward(...)`, and `Tape.runValidate(...)` provide lifecycle helpers over the existing explicit tape model. `quadrants.ad.Grad`, `GradCheck`, and `CustomGradient` add gradient zeroing, finite-difference checking for F32 tensor-to-scalar kernels, and explicit custom forward/backward kernel pairing.

`quadrants.coverage.Coverage` records kernel builds, launches, and descriptor source-span probe counts, then writes JSON artifacts with `Coverage.flush(path)`. `quadrants.compat.Diagnostics` exposes descriptor dumps, descriptor hashes, value info, and runtime health checks.

## Packed data, SNode helpers, sparse, and profiler bridge

`quadrants.packed` provides workaround storage for non-scalar data without claiming final native compound-field parity. `PackedVectorTensor<T>` / `PackedVectorField<T>` and `PackedMatrixTensor<T>` / `PackedMatrixField<T>` store logical vectors or matrices in typed primitive `Tensor<T>` / `Field<T>` storage, while `PackedStructTensor` and `StructOfArraysField` keep named primitive members in separate tensors/fields. Prefer `StructMember<T>` plus `addMember` / `readMember` / `writeMember` for typed struct member access; the string-keyed `Dynamic` methods are compatibility shims. Kernel helper calls such as `PackedHelpers.readVec2I32(...)` and `PackedHelpers.writeVec2I32(...)` lower to scalar tensor loads/stores.

`VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, `MatrixField<T>`, and `StructField` are the first-class compound storage names. Vector/matrix containers are typed wrappers around primitive `Tensor<T>` / `Field<T>` flat storage with native `TensorHandle` launch behavior and kernel methods such as `readVec2(...)`, `writeVec2(...)`, `readMat2(...)`, and `writeMat2(...)`; `StructField` keeps named field members in a supported SOA layout. `fromPacked(...)` / `toPacked()` adapters preserve the Phase 6 migration path.

`FieldsBuilder.placeMany(...)`, `FieldsBuilder.finalize()`, `quadrants.snode.FieldPlacementPath`, `quadrants.snode.FieldTree`, and `quadrants.runtime.LoopConfig` centralize placement and loop-control ergonomics while keeping explicit `Context` ownership.

`quadrants.linalg` exposes the first native sparse bridge: `SparseMatrix`, `SparseMatrixBuilder`, `SparseSolver`, and `SparseCG` for F32 sparse CPU/runtime smoke usage. `quadrants.profiler.ProfilerBridge` reports profiler feature availability and `ScopedProfiler.run(...)` wraps named profiler scopes.

`CompilerHints.assumeInRange(value, base, low, high)` lowers to the native range-assumption IR expression. Other deep compiler hints remain unavailable unless the runtime/compiler exposes a concrete hook.

`bindings/hashlink/haxe/quadrants/DYNAMIC_BOUNDARIES.md` records every retained public `Dynamic` boundary and whether it is a permanent interop boundary or a compatibility shim.


## API surface

The supported public API includes `Context`, `quadrants.runtime.Runtime` / `Session`, `Kernel`, primitive `Tensor` ndarrays, streams/events, profiler queries, `quadrants.simt` helpers, `quadrants.algorithms`, `quadrants.ad` workflow utilities, `quadrants.coverage.Coverage`, `quadrants.compat.Diagnostics`, first-class `VectorNdarray` / `MatrixNdarray` / `VectorField` / `MatrixField` / `StructField` compound containers, `CompilerHints.assumeInRange`, `quadrants.packed` workaround containers, `quadrants.snode` builder helpers, `quadrants.linalg` sparse bridge APIs, `quadrants.profiler` bridge helpers, `Arch`, and `DType`. Python decorators, NumPy/Torch interop, and Python environment integrations are not part of this HashLink package.

## Troubleshooting

- Bridge not loaded: re-run `haxe` with `QUADRANTS_HDLL` pointing at the built `quadrants.hdll`, or put the bridge directory on the dynamic-library search path.
- Missing `runtime_*.bc` or `slim_libdevice.10.bc`: set `QD_LIB_DIR` or `QUADRANTS_RUNTIME_DIR` to the runtime directory.
- Backend context creation fails: rebuild `quadrants.hdll` with the corresponding `QD_WITH_*` option and verify the driver/runtime is installed.
- Macro reports `Unsupported Quadrants HashLink ...`: the kernel uses syntax outside the supported DSL subset.
