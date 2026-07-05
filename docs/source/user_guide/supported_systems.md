# Supported systems for Haxe/HashLink

The Haxe binding requires both the Haxe/HashLink toolchain and the native Quadrants backend libraries. The public execution path is HashLink bytecode plus the HashLink JIT (`haxe -hl app.hl`, then `hl app.hl`).

## Host requirements

- CMake and a C++17 compiler for building `quadrants.hdll`.
- `haxe` and `hl` on `PATH` for compiling and running user programs.
- A HashLink checkout or install that provides `hl.h` and `libhl`/`hl.dll`.
- LLVM/Clang 22 or newer and `LLVMConfig.cmake` when `Arch.Cpu`, `Arch.Cuda`, or `Arch.Amdgpu` are enabled.

## Tested CI configuration

The staged CI path builds and tests the HashLink bridge on Ubuntu 22.04 x86_64 with Haxe, HashLink built from source, LLVM/Clang 22, and the CPU JIT backend.

## Backend matrix

| Host platform | `Arch.Cpu` | `Arch.Cuda` | `Arch.Vulkan` | `Arch.Metal` | `Arch.Amdgpu` |
| --- | --- | --- | --- | --- | --- |
| Linux x86_64 | yes | with NVIDIA driver/CUDA | with Vulkan loader/driver | no | with ROCm/HIP |
| Linux ARM64 | yes | not currently supported by Quadrants | with Vulkan loader/driver | no | not currently supported |
| macOS Apple Silicon | yes | no | with Vulkan/MoltenVK build | yes | no |
| Windows x86_64 | not covered by current HashLink CI | with NVIDIA driver/CUDA when enabled | with Vulkan loader/driver when enabled | no | no |

Notes:

- `Arch.Cpu` maps to the host LLVM backend and needs `runtime_x64.bc` or `runtime_arm64.bc` available next to `quadrants.hdll`, through `QD_LIB_DIR`, or through the installed layout.
- `Arch.Cuda` also needs `runtime_cuda.bc`, `slim_libdevice.10.bc`, CUDA driver libraries, and a native build configured with `QD_WITH_CUDA=ON`.
- `Arch.Amdgpu` needs the AMDGPU runtime bitcode and ROCm device libraries installed by the HashLink component.
- `Arch.Vulkan` and `Arch.Metal` do not use LLVM runtime bitcode, but they do need the corresponding native backend compiled into `quadrants.hdll`.
- When the native build enables `QD_WITH_CUDA` or `QD_WITH_AMDGPU`, CTest also registers `hashlink_v3_cuda_backend_semantic` / `hashlink_v3_amdgpu_backend_semantic`. These optional backend-depth tests run stream-event ordering and multi-stream `Graph.parallel` stress cases when a device is present, and report a structured skip when the backend cannot create a runtime context.

## HashLink library loading

At run time, `hl` must be able to load `quadrants.hdll`, `libhl`, and any backend driver libraries. Install `quadrants.hdll` like HashLink native extensions such as `sdl.hdll`/`openal.hdll`: either into the same prefix/libdir as the `hl` executable, next to a HashLink checkout's `hl`, or onto the platform dynamic-library path. Use the platform dynamic-library path when necessary:

- Linux: `LD_LIBRARY_PATH`
- macOS: `DYLD_LIBRARY_PATH`
- Windows: `PATH`

The haxelib package only provides Haxe interface code. Native setup is separate: `hashlink_native` or `scripts/install_hashlink_native.sh` installs `quadrants.hdll` and runtime bitcode. Compiled `.hl` files use the logical native library name `quadrants`, so moving native files requires updating the HashLink native setup, not recompiling Haxe bytecode.
