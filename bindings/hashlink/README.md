# Quadrants Haxe/HashLink bindings

This directory is a haxelib-compatible package root for the Quadrants HashLink interface. Haxe programs compile to HashLink bytecode (`haxe -hl ...`) and execute through the HashLink JIT (`hl ...`). The native bridge `quadrants.hdll` is installed separately as a HashLink native extension, like `sdl.hdll` or `openal.hdll`.

## Installed layout

```text
lib/quadrants.hdll                         # or the platform HashLink native-library directory
share/quadrants/hashlink/haxelib.json
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

## Native setup and haxelib package

A CPU + CUDA native setup should install `quadrants.hdll`, `runtime_x64.bc` or `runtime_arm64.bc`, `runtime_cuda.bc`, and `slim_libdevice.10.bc`. Configure the CMake build with `QD_WITH_HASHLINK=ON`, `QD_WITH_LLVM=ON`, and `QD_WITH_CUDA=ON` before installing. For the common user-level CPU+CUDA+Vulkan flow, use `scripts/package_hashlink_user_level.sh`; it builds with `-j2`, installs native artifacts under `$HOME/.local`, and installs the Haxe interface zip into haxelib.

```bash
scripts/package_hashlink_user_level.sh
```

Manual native/system setup:

```bash
QD_BUILD_DIR="$PWD/build/hashlink"
cmake --build "$QD_BUILD_DIR" --target quadrants.hdll
cmake --install "$QD_BUILD_DIR" --component hashlink_native --prefix /usr/local
scripts/package_hashlink_haxelib.sh \
  --build-dir "$QD_BUILD_DIR" \
  --runtime-dir "$QD_BUILD_DIR/runtime" \
  --out build/quadrants-haxelib.zip
haxelib --global install build/quadrants-haxelib.zip --always
```

`hashlink_native` installs `quadrants.hdll` to the install libdir and runtime bitcode under `share/quadrants/hashlink/runtime`. Use a user prefix for no-sudo setup, for example `--prefix "$HOME/.local"`, together with a HashLink executable installed in the same prefix. For a HashLink checkout/build tree, `scripts/install_hashlink_native.sh --build-dir "$QD_BUILD_DIR" --hashlink-dir "$QD_HASHLINK_ROOT"` copies `quadrants.hdll` next to `hl` and runtime files under `$QD_HASHLINK_ROOT/quadrants/runtime`.

The haxelib zip contains only the Haxe interface code; the package script uses the selected `quadrants.hdll` and runtime directory for validation. If the native-symbol check fails, rebuild `quadrants.hdll`; use `--skip-native-symbol-check` only when deliberately packaging without a native validation step. Vulkan/Metal-only packages without LLVM bitcode should pass `--allow-no-runtime`.

For development from a CMake install tree, install the interface component and use `haxelib dev`:

```bash
QD_INSTALL_DIR="$PWD/build/hashlink-install"
cmake --install "$QD_BUILD_DIR" --component hashlink_haxelib --prefix "$QD_INSTALL_DIR"
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
haxe -lib quadrants -cp tests/hashlink/v3 -main Smoke -hl build/hashlink-v3-smoke-cuda.hl
QD_HASHLINK_TEST_ARCHES=cuda \
LD_LIBRARY_PATH="/usr/local/cuda/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}" \
hl build/hashlink-v3-smoke-cuda.hl
```

For a build-tree run without installing into `/usr/local`, either put the build directory on the dynamic-library path while running `hl`, or copy the native files into the HashLink checkout next to `hl`:

```bash
cp "$QD_BUILD_DIR/quadrants.hdll" "$QD_HASHLINK_ROOT/quadrants.hdll"
mkdir -p "$QD_HASHLINK_ROOT/quadrants/runtime"
cp -p "$QD_BUILD_DIR/runtime/"* "$QD_HASHLINK_ROOT/quadrants/runtime/"
```

After that, Haxe bytecode remains portable because it records only the logical native library name `quadrants`:

```bash
haxe tests/hashlink/v3/hashlink_v3_smoke.hxml -hl build/hashlink-v3-smoke-buildtree.hl
hl build/hashlink-v3-smoke-buildtree.hl
```

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

## Compound storage, SNode helpers, sparse, and profiler bridge

`VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, `MatrixField<T>`, `StructTensor<S>`, and `StructField<S>` are the first-class compound storage names, with N-D batch shapes and AOS/SOA layout control. Vector/matrix containers expose kernel methods such as `readVec2(...)`, `writeVec2(...)`, `readMat2(...)`, and `writeMat2(...)`; struct storage uses `@:build(quadrants.macro.QdStruct.build())` element types.

`FieldsBuilder.placeMany(...)`, `FieldsBuilder.finalize()`, `quadrants.snode.FieldPlacementPath`, `quadrants.snode.FieldTree`, `quadrants.snode.RescaleIndex`, and `quadrants.runtime.LoopConfig` centralize placement and loop-control ergonomics while keeping explicit `Context` ownership. Placement offsets may be negative, and `quadrants.sparse.SparseGrid` builds bitmasked struct-of-arrays grids with `usage()` occupancy reporting.

`quadrants.linalg` exposes the native sparse bridge: `SparseMatrix`, `SparseMatrixBuilder`, `SparseSolver`, and `SparseCG` for F32/F64 COO/CSR usage with explicit host-dense fallback policy. `ContextOptions` applies every typed native-backed context setting at creation (offline-cache eviction, compile options, debug/timeline, memory limits), and `quadrants.profiler` provides feature probes, scoped profiler blocks, per-launch trace listings, print/clear convenience, typed CUPTI metric presets, and typed memory-profiler counters.

`CompilerHints.assumeInRange(value, base, low, high)` lowers to the native range-assumption IR expression. Other deep compiler hints (block-local storage, cache hints, loop uniqueness) remain unavailable unless the runtime/compiler exposes a concrete hook.

`quadrants.mesh` adds typed host-side mesh domains, elements, relations, and attributes (`MeshKinds.vertex`, `MeshRelation<Vertex, Face>`, `MeshAttribute<Vertex, T>`); relation/attribute kernel parameters lower through QDHL mesh resource metadata.

`quadrants.quant` adds typed quant storage descriptors (`QuantBits` with 8/16/32/64-bit physical widths, `QuantSignedness`, `QuantStorageSpec<T>`), quantized tensor kernel parameters, and quant-array/bit-struct SNode placement.

`docs/source/user_guide/dynamic_boundaries.md` records every retained public `Dynamic` boundary and whether it is a permanent interop boundary or a compatibility shim.

Release-readiness status, API classification, backend support tables, and performance-baseline guidance are summarized in `docs/source/user_guide/haxe_release_readiness.md`.


## API surface

The supported public API includes `Context`, `ContextOptions`, `Extension`, `quadrants.runtime.Runtime` / `Session`, `Kernel`, primitive `Tensor` ndarrays, streams/events, profiler queries, `quadrants.simt` helpers, `quadrants.algorithms`, `quadrants.ad` workflow utilities, `quadrants.coverage.Coverage`, `quadrants.compat.Diagnostics` / `PerfBaseline`, first-class `VectorNdarray` / `MatrixNdarray` / `VectorField` / `MatrixField` / `StructField` compound containers, `StructMember<T>`, `CompilerHints.assumeInRange`, `quadrants.packed` workaround containers, `quadrants.snode` builder helpers, `quadrants.mesh` host-side typed mesh handles, `quadrants.quant` descriptors/reference storage, `quadrants.linalg` sparse bridge APIs, `quadrants.profiler` bridge helpers, `Arch`, and `DType`. Python decorators, NumPy/Torch interop, and Python environment integrations are not part of this HashLink package.

## Troubleshooting

- Bridge not loaded: install `quadrants.hdll` as a HashLink native extension (`hashlink_native`, `scripts/install_hashlink_native.sh`, or the platform dynamic-library path).
- Missing `runtime_*.bc` or `slim_libdevice.10.bc`: install the runtime next to the native bridge or set `QD_LIB_DIR` / `QUADRANTS_RUNTIME_DIR` to the runtime directory.
- Backend context creation fails: rebuild `quadrants.hdll` with the corresponding `QD_WITH_*` option and verify the driver/runtime is installed.
- Macro reports `Unsupported Quadrants HashLink ...`: the kernel uses syntax outside the supported DSL subset.
