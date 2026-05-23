# Quadrants Haxe/HashLink bindings

This directory is a haxelib-compatible package root for the Quadrants HashLink bridge (`quadrants.hdll`). Haxe programs compile to HashLink bytecode (`haxe -hl ...`) and execute through the HashLink JIT (`hl ...`). The canonical CMake install layout is under `share/quadrants/hashlink`.

## Installed layout

```text
share/quadrants/hashlink/haxelib.json
share/quadrants/hashlink/quadrants.hdll
share/quadrants/hashlink/README.md
share/quadrants/hashlink/haxe/quadrants/*.hx
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

## API surface

The supported public API is `Context`, `Kernel`, primitive `Tensor` ndarrays, `Arch`, and `DType`. The old Python modules (`quadrants.ad`, `quadrants.linalg`, `quadrants.sparse`, Python decorators, NumPy/Torch interop, and Python fields/SNode helpers) are not part of this HashLink package.

## Troubleshooting

- Bridge not loaded: re-run `haxe` with `QUADRANTS_HDLL` pointing at the built `quadrants.hdll`, or put the bridge directory on the dynamic-library search path.
- Missing `runtime_*.bc` or `slim_libdevice.10.bc`: set `QD_LIB_DIR` or `QUADRANTS_RUNTIME_DIR` to the runtime directory.
- Backend context creation fails: rebuild `quadrants.hdll` with the corresponding `QD_WITH_*` option and verify the driver/runtime is installed.
- Macro reports `Unsupported Quadrants HashLink ...`: the kernel uses syntax outside the supported DSL subset.
