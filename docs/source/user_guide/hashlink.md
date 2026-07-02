# Haxe/HashLink integration

Quadrants is distributed for Haxe through a haxelib-compatible source package and the native HashLink bridge `quadrants.hdll`. Haxe macros build kernel descriptors at compile time; the native bridge creates Quadrants contexts, allocates ndarrays, compiles kernels, launches kernels, and synchronizes.

## Prerequisites

- `haxe` and `hl` on `PATH`.
- A HashLink checkout or install. Set `QD_HASHLINK_ROOT` to a prefix containing `src/hl.h` or `include/hl.h`, plus `libhl`/`hl.dll`.
- LLVM/Clang 22 or newer and `LLVMConfig.cmake` when CPU, CUDA, or AMDGPU backends are enabled.
- Backend drivers/runtime libraries available to `hl` at run time.

## Backend support

| Haxe arch | Native backend | Build-time requirement | Runtime requirement |
| --- | --- | --- | --- |
| `Arch.Cpu` | Host LLVM backend (`x64`/`arm64`) | `QD_WITH_LLVM=ON` | host runtime bitcode, e.g. `runtime_x64.bc` |
| `Arch.Cuda` | CUDA | `QD_WITH_LLVM=ON`, `QD_WITH_CUDA=ON` | CUDA driver libraries, `runtime_cuda.bc`, `slim_libdevice.10.bc` |
| `Arch.Vulkan` | Vulkan/SPIR-V | `QD_WITH_VULKAN=ON` | Vulkan loader/driver libraries visible to `hl` |
| `Arch.Metal` | Metal | macOS, `QD_WITH_METAL=ON` | Metal runtime on macOS |
| `Arch.Amdgpu` | AMDGPU/ROCm | Linux x64, `QD_WITH_LLVM=ON`, `QD_WITH_AMDGPU=ON` | ROCm/HIP libraries and ROCm device bitcode |

CUDA/OpenGL interop additionally requires `QD_WITH_CUDA=ON` with the CUDA toolkit found by CMake (sets `QD_HASHLINK_CUDA_GL_INTEROP`).

## Build and install

```bash
QD_BUILD_DIR="$PWD/build/hashlink"
QD_INSTALL_DIR="$PWD/build/hashlink-install"
QD_HASHLINK_ROOT="${QD_HASHLINK_ROOT:-/path/to/hashlink}"

cmake -S . -B "$QD_BUILD_DIR" \
  -DQD_WITH_HASHLINK=ON \
  -DQD_HASHLINK_ROOT="$QD_HASHLINK_ROOT" \
  -DQD_WITH_LLVM=ON \
  -DQD_WITH_CUDA=OFF \
  -DQD_WITH_VULKAN=OFF \
  -DQD_WITH_METAL=OFF \
  -DQD_WITH_AMDGPU=OFF
cmake --build "$QD_BUILD_DIR" --target quadrants.hdll
rm -rf "$QD_INSTALL_DIR"
cmake --install "$QD_BUILD_DIR" --component hashlink --prefix "$QD_INSTALL_DIR"
```

For a CPU + CUDA HashLink package, enable CUDA in the same build:

```bash
cmake -S . -B "$QD_BUILD_DIR" \
  -DQD_WITH_HASHLINK=ON \
  -DQD_HASHLINK_ROOT="$QD_HASHLINK_ROOT" \
  -DQD_WITH_LLVM=ON \
  -DQD_WITH_CUDA=ON \
  -DQD_WITH_VULKAN=OFF \
  -DQD_WITH_METAL=OFF \
  -DQD_WITH_AMDGPU=OFF
cmake --build "$QD_BUILD_DIR" --target quadrants.hdll
```

The `quadrants.hdll` target depends on the required host/runtime bitcode targets for the enabled backends. A CUDA package must include `runtime_cuda.bc` and `slim_libdevice.10.bc` next to the CPU runtime bitcode.

## Installed layout

```text
share/quadrants/hashlink/haxelib.json
share/quadrants/hashlink/quadrants.hdll
share/quadrants/hashlink/README.md
share/quadrants/hashlink/haxe/quadrants/*.hx
share/quadrants/hashlink/haxe/quadrants/macro/*.hx
share/quadrants/hashlink/runtime/runtime_x64.bc
share/quadrants/hashlink/runtime/runtime_cuda.bc       # CUDA builds
share/quadrants/hashlink/runtime/slim_libdevice.10.bc  # CUDA builds
```

Register the installed haxelib package root for development:

```bash
haxelib dev quadrants "$QD_INSTALL_DIR/share/quadrants/hashlink"
```

Or package the build tree and install it into the global haxelib repository:

```bash
scripts/package_hashlink_haxelib.sh \
  --build-dir "$QD_BUILD_DIR" \
  --runtime-dir "$QD_BUILD_DIR/runtime" \
  --out build/quadrants-haxelib.zip
haxelib --global install build/quadrants-haxelib.zip --always
```

The package script stages `quadrants.hdll`, Haxe sources, the top-level `LICENSE`, and top-level files from `runtime/`. It also validates that the selected `quadrants.hdll` exports the `@:hlNative` functions used by the current Haxe sources and that `runtime/` contains host `runtime_*.bc` bitcode. If `runtime_cuda.bc` is present but `slim_libdevice.10.bc` is missing, it copies `external/cuda_libdevice/slim_libdevice.10.bc` into the package. Use `--skip-native-symbol-check` only when deliberately packaging a different Haxe/native pair; use `--allow-no-runtime` for Vulkan/Metal-only packages without LLVM bitcode.

The Haxe macros discover `quadrants.hdll` and the package-local `runtime` directory from that haxelib root. If a build tree or moved install tree is used, set `QUADRANTS_HDLL` and `QUADRANTS_RUNTIME_DIR` while compiling the `.hl` file. The same values can be supplied as Haxe defines: `-D quadrants_hdll_path=/path/to/quadrants.hdll` and `-D quadrants_runtime_dir=/path/to/runtime`.

## Running tests

CTest entries are registered when `QD_WITH_HASHLINK=ON` and `QD_BUILD_HASHLINK_TESTS=ON` (with `haxe` and `hl` on `PATH`). Add `-DQD_BUILD_HASHLINK_TESTS=ON` to the configure command above, then run:

```bash
cmake --build "$QD_BUILD_DIR" --target quadrants.hdll
ctest --test-dir "$QD_BUILD_DIR" --output-on-failure
```

The CTest suite is the HashLink gate: it compiles and runs `tests/hashlink/v3/hashlink_v3_smoke.hxml`, runs `tests/hashlink/hashlink_tests.hxml` as the runtime semantic suite, runs descriptor golden snapshots from `tests/hashlink/descriptor/hashlink_descriptor_golden.hxml`, verifies Haxe macro compile-fail cases in `tests/hashlink/compile_fail/`, scans public `Dynamic` boundaries, and validates the haxelib package zip layout via `hashlink_package_validate`.

When the native build enables CUDA or AMDGPU, CTest also registers optional backend-depth tests (`hashlink_v3_cuda_backend_semantic` / `hashlink_v3_amdgpu_backend_semantic`). These tests attempt to create the requested device context, run stream-event ordering and multi-stream `Graph.parallel` stress cases when possible, and print a structured skip when the device/runtime is unavailable.

## Build/test helper entry points

| Purpose | Haxe/HL entry point |
| --- | --- |
| Build/install the Haxe package and native bridge | CMake with `-DQD_WITH_HASHLINK=ON`, target `quadrants.hdll`, and `cmake --install --component hashlink`. |
| Package and install into global haxelib | `scripts/package_hashlink_haxelib.sh --build-dir <build> --runtime-dir <build>/runtime --out build/quadrants-haxelib.zip`, then `haxelib --global install ...`. |
| Compile and run the v3 smoke test | `tests/hashlink/v3/hashlink_v3_smoke.hxml` through `ctest` (`hashlink_haxe_compile`, `haxe_v3_smoke`). |
| Run descriptor schema snapshots | `tests/hashlink/descriptor/hashlink_descriptor_golden.hxml` through `ctest` (`hashlink_descriptor_golden`). |
| Run macro diagnostics | `cmake/RunHaxeCompileFailTests.cmake` through `ctest` (`hashlink_macro_compile_fail`). |
| Run public Dynamic boundary scan | `tools/check_public_dynamic.sh` through `ctest` (`hashlink_public_dynamic_scan`). |
| Run optional CUDA/AMDGPU stream-depth coverage | Configure with `QD_WITH_CUDA=ON` or `QD_WITH_AMDGPU=ON`; CTest registers `hashlink_v3_cuda_backend_semantic` / `hashlink_v3_amdgpu_backend_semantic`. |
| Run the CUDA bridge sample manually | `bindings/hashlink/tests/hashlink_bridge_test.hxml` when `QD_WITH_CUDA=ON` and CUDA libraries are visible to `hl`. |
| Check macro diagnostics | `cmake/RunHaxeCompileFailTests.cmake` over `tests/hashlink/compile_fail/*.hx`. |
| Build docs for the Haxe public API | `haxelib install dox` once, then `make -C docs html`. |

Manual smoke test from an installed haxelib package:

```bash
haxe -lib quadrants -cp tests/hashlink/v3 -main Smoke -hl build/hashlink-v3-smoke.hl
hl build/hashlink-v3-smoke.hl
```

CUDA smoke tests are opt-in because they require CUDA runtime libraries and hardware:

```bash
QD_HASHLINK_TEST_ARCHES=cuda \
haxe -lib quadrants -cp tests/hashlink/v3 -main Smoke -hl build/hashlink-v3-smoke-cuda.hl
QD_HASHLINK_TEST_ARCHES=cuda \
LD_LIBRARY_PATH="/usr/local/cuda/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}" \
hl build/hashlink-v3-smoke-cuda.hl
```

Expected output:

```text
hashlink v3 smoke ok
```

Manual build-tree run:

```bash
QUADRANTS_HDLL="$QD_BUILD_DIR/quadrants.hdll" \
QUADRANTS_RUNTIME_DIR="$QD_BUILD_DIR/runtime" \
haxe tests/hashlink/v3/hashlink_v3_smoke.hxml -hl build/hashlink-v3-smoke-buildtree.hl
QD_LIB_DIR="$QD_BUILD_DIR/runtime" \
LD_LIBRARY_PATH="$QD_BUILD_DIR:${LD_LIBRARY_PATH:-}" \
hl build/hashlink-v3-smoke-buildtree.hl
```

For the typed public API, see [Haxe/HashLink API](haxe_api.md). For accepted kernel syntax, see [Haxe kernels](haxe_kernel_v3.md) and [Haxe kernel language](kernel_language.md).

## Minimal API

```haxe
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

var ctx = Context.create({arch: Arch.Cpu});
var a = new Tensor<I32>(ctx, [16]);
var b = new Tensor<I32>(ctx, [16]);
var out = new Tensor<I32>(ctx, [16]);

for (i in 0...16) {
  a.write(i, i * 2);
  b.write(i, 100 - i);
}

final k = Kernel.build(ctx, macro (a:Tensor<I32>, b:Tensor<I32>, out:Tensor<I32>, n:Int) -> {
  for (i in 0...n) {
    out[i] = a[i] + b[i];
  }
});

k.launch(a, b, out, 16);
ctx.sync();

k.close();
ctx.close();
```

Primitive tensors are allocated with `new Tensor<T>(ctx, shape)`, where `T` is one of `I8`, `I16`, `I32`, `I64`, `U8`, `U16`, `U32`, `U64`, `U1`, `F16`, `F32`, or `F64`. Host access uses the typed `fill`, `read`, `write`, `readAt`, `writeAt`, `toArray`, and `fromArray` methods.

## Kernel macro coverage

The current Haxe macro supports:

- Primitive scalar and `Tensor<T>` parameters.
- Ndarray indexing, including nested indexing up to rank 8.
- `for (i in start...end)`, typed `Ndrange.ofN(...)`/`Ndrange.rangesN(...)` loops, `Ndrange.ofNAxes(...)`/`rangesNAxes(...)` loops with `AxisOrder.ofN(...)` permutations, `for (i in fieldOrTensor)`, `for (i in Static.range(...))`, `while`, `break`, and `continue`.
- `if` statements, compile-time literal `if (true)` / `if (false)`, expression-level `if`/select, and Haxe ternary expressions.
- Local variable declarations and assignments.
- Ndarray element stores, atomic compound assignment on ndarray elements, and `atomicAdd(a[i], value)`/related fetch-atomic expressions, including `atomicCompareExchange(a[i], expected, desired)`.
- Arithmetic, comparison, boolean, integer bitwise, unary `!`, unary `-`, and bitwise `~` expressions.
- Vector locals via `Vec2`/`Vec3`/`Vec4` or `Vector.ofArray`, including component/index access, elementwise arithmetic, `dot`, `cross`, `norm`, and `normalized`.
- Matrix locals via `Mat2`/`Mat3`/`Mat4` or `Matrix.ofArray`, including constant row/column indexing, elementwise arithmetic, `matmul`, and `transpose`.
- Shared arrays via `Shared.array*(size)` and fixed 16x16 tiles via `Shared.tile16*()` for primitive dtypes with direct indexing in kernel bodies.
- Struct locals from `Struct.ofN("field", value, ...)` with scalar field access and assignment.
- `abs`, `sin`, `asin`, `cos`, `acos`, `tan`, `atan`, `tanh`, `exp`, `log`, `sqrt`, `rsqrt`, `floor`, `ceil`, `round`, `min`, `max`, `atan2`, `pow`, `inv`, `rcp`, `popcnt`, `clz`, `ffs`, `sgn`, `isnan`, `isinf`, and `select(cond, a, b)`.
- Random scalar calls: `randI32()`, `randU32()`, `randF32()`, and `randF64()`.
- Explicit casts and `bitCast` to supported primitive scalar types.
- `print(...)` and `assert(...)` frontend statements.
- Primitive scalar return values via the typed wrapper return value, e.g. `var value = k.launch(args...)`.
- Autodiff descriptor rebuild helpers (`Kernel.grad()`, `forwardGrad()`, `validationKernel()`) and `Tape` replay for recorded launches.
- Typed `Ndrange.ofN` domains, `shape(tensor, axis)`, loop hints (`blockDim`, `parallelize`, `serialize`), `@:qdFunc` helper calls, `Grid.threadIdx()`, and `Block`/`Subgroup`/`Workgroup` SIMT helpers inside lowered loops.
- Specialization constants through explicit `Spec<T>` parameters or primitive `QdArgs` members.
- Flattened struct returns that can be decoded on the host with `Struct.decodeSchema(...)`.
- External-pointer and DLPack tensor import/export on LLVM-backed backends (`Cpu`, `Cuda`, `Amdgpu`).
- Stream events (`Stream.createEvent()`, `recordEvent`, `waitEvent`) on CUDA/AMDGPU contexts.

Unsupported constructs are rejected by the Haxe macro with `Unsupported Quadrants HashLink ...` diagnostics.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Quadrants HashLink native bridge is not loaded` | Re-run `haxe` with `QUADRANTS_HDLL` set to the built `quadrants.hdll`, or use the installed haxelib layout and make the bridge directory visible to the dynamic loader. |
| HashLink cannot load `libhl`, CUDA, ROCm, Vulkan, or another native dependency | Add the HashLink library directory and backend SDK library directories to `LD_LIBRARY_PATH` on Linux, `DYLD_LIBRARY_PATH` on macOS, or `PATH` on Windows. |
| `Bitcode file (.../runtime_*.bc) not found` | Set `QD_LIB_DIR` at run time or `QUADRANTS_RUNTIME_DIR` while compiling to the directory containing the required `.bc` files. CUDA also needs `slim_libdevice.10.bc`. |
| Context creation fails for a non-CPU backend | Verify the backend was enabled in the native build and that the host driver/runtime is installed. |
| A moved install tree no longer works | Re-run `haxe`; `QUADRANTS_HDLL` and the discovered runtime path are compile-time macro inputs. |
| Kernel launch reports argument count, dtype, rank, or context mismatch | Launch with the same parameter count and tensor ranks/dtypes used by `Kernel.build`; do not mix tensors from different `Context` objects. |
| Shutdown crashes or use-after-close errors | Close kernels before closing their context. Native finalizers are only a safety net. |
| `CudaGlInterop.available(ctx)` returns `false` on a CUDA context | Build `quadrants.hdll` with `QD_WITH_CUDA=ON` and ensure CMake finds the CUDA toolkit (sets `QD_HASHLINK_CUDA_GL_INTEROP`). |
