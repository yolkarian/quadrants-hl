# Quadrants

[🌐 Documentation website](https://yolkarian.github.io/quadrants-hl/)

Quadrants is a high-performance multi-platform compiler for physics simulation workloads. It now targets the Haxe/HashLink ecosystem through a native HashLink library (`quadrants.hdll`) plus haxelib-compatible Haxe sources.

Supported native backends include:

- x86_64 and ARM64 CPU through LLVM
- NVIDIA GPUs through CUDA
- Vulkan-compatible GPUs through SPIR-V
- Apple Metal GPUs
- AMD GPUs through ROCm/HIP

## Haxe/HashLink quick start

Prerequisites:

- CMake and a C++17 compiler
- LLVM/Clang 22 or newer with `LLVMConfig.cmake`
- `haxe` and `hl` on `PATH`
- a HashLink checkout or install containing `src/hl.h` or `include/hl.h` and `libhl`

Build and install the HashLink component:

```bash
cmake -S . -B build/hashlink \
  -DQD_WITH_HASHLINK=ON \
  -DQD_HASHLINK_ROOT=/path/to/hashlink \
  -DQD_WITH_LLVM=ON
cmake --build build/hashlink --target quadrants.hdll generate_llvm_runtime_x64
cmake --install build/hashlink --component hashlink --prefix build/install
```

Register the Haxe package and run the smoke test:

```bash
haxelib dev quadrants "$PWD/build/install/share/quadrants/hashlink"
haxe -lib quadrants -cp tests/hashlink -main Smoke -hl build/hashlink-smoke.hl
hl build/hashlink-smoke.hl
```

The installed haxelib package is rooted at `share/quadrants/hashlink` and contains `quadrants.hdll`, Haxe sources under `haxe/`, and runtime bitcode under `runtime/`.

## Documentation

- [Getting started with Haxe/HashLink](docs/source/user_guide/getting_started.md)
- [Haxe/HashLink integration](docs/source/user_guide/hashlink.md)
- [Haxe/HashLink public API](docs/source/user_guide/haxe_api.md)
- [User guide](https://genesis-embodied-ai.github.io/quadrants/user_guide/index.html)

## Origin

The original Python version of Quadrants was forked from [Taichi](https://github.com/taichi-dev/taichi) in June 2025. This branch is derived from the Python Quadrants repository at [Genesis-Embodied-AI/quadrants](https://github.com/Genesis-Embodied-AI/quadrants) and continues its evolution toward an independent Haxe/HashLink compiler project.
