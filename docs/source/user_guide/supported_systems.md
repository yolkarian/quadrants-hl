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

- `Arch.Cpu` maps to the host LLVM backend and needs `runtime_x64.bc` or `runtime_arm64.bc` available through `QD_LIB_DIR` or the installed layout.
- `Arch.Cuda` also needs `runtime_cuda.bc`, `slim_libdevice.10.bc`, CUDA driver libraries, and a native build configured with `QD_WITH_CUDA=ON`.
- `Arch.Amdgpu` needs the AMDGPU runtime bitcode and ROCm device libraries installed by the HashLink component.
- `Arch.Vulkan` and `Arch.Metal` do not use LLVM runtime bitcode, but they do need the corresponding native backend compiled into `quadrants.hdll`.
- Optional device smoke tests are selected with `QD_HASHLINK_TEST_ARCHES=cpu,cuda,vulkan,metal,amdgpu` or `QD_HASHLINK_TEST_ARCHES=all`.

## HashLink library loading

At run time, `hl` must be able to load `quadrants.hdll`, `libhl`, and any backend driver libraries. Use the platform dynamic-library path when necessary:

- Linux: `LD_LIBRARY_PATH`
- macOS: `DYLD_LIBRARY_PATH`
- Windows: `PATH`

The installed haxelib layout lets the Haxe macro find `quadrants.hdll` and the runtime bitcode automatically. Build-tree runs should set `QUADRANTS_HDLL` and `QUADRANTS_RUNTIME_DIR` while invoking `haxe`.
