#!/bin/bash

set -eux

if command -v clang-22 >/dev/null 2>&1; then
  LLVM_VERSION=22
elif command -v clang-15 >/dev/null 2>&1; then
  LLVM_VERSION=15
else
  echo "No supported clang found" >&2
  exit 1
fi

cmake -S . -B build/clang-tidy -G Ninja \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER="/usr/bin/clang-${LLVM_VERSION}" \
  -DCMAKE_CXX_COMPILER="/usr/bin/clang++-${LLVM_VERSION}" \
  -DLLVM_DIR="/usr/lib/llvm-${LLVM_VERSION}/lib/cmake/llvm" \
  -DCLANG_EXECUTABLE="/usr/bin/clang-${LLVM_VERSION}" \
  -DQD_WITH_HASHLINK=OFF \
  -DQD_WITH_LLVM=ON \
  -DQD_WITH_CUDA=OFF \
  -DQD_WITH_VULKAN=OFF \
  -DQD_WITH_METAL=OFF \
  -DQD_WITH_AMDGPU=OFF
