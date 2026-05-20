#!/bin/bash

set -eux

sudo apt-get update
sudo apt-get install -y \
  clang-15 \
  clang-tidy-15 \
  cmake \
  llvm-15-dev \
  ninja-build

git submodule update --init --recursive
