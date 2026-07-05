#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build and install a user-level Quadrants HashLink setup, then package/install the
Haxe interface into haxelib.

Defaults are intentionally user-local and low-parallelism:
  prefix:     $HOME/.local
  HashLink:   $HOME/.local
  backends:   CPU + CUDA + Vulkan
  jobs:       2

Usage:
  scripts/package_hashlink_user_level.sh [options]

Options:
  --prefix DIR           User-level install prefix. Default: $HOME/.local
  --hashlink-root DIR    HashLink install/checkout containing include/hl.h or src/hl.h. Default: --prefix
  --build-dir DIR        CMake build directory. Default: build/hashlink-user-cpu-cuda-vulkan
  --out FILE             Haxelib zip path. Default: build/quadrants-haxelib-user.zip
  --jobs N               Build parallelism. Default: 2
  --no-haxelib-install   Build the zip but do not run haxelib install.
  --global-haxelib       Install the haxelib zip with haxelib --global.
  -h, --help             Show this help.

The native install uses the CMake hashlink_native component and installs:
  <prefix>/lib/quadrants.hdll
  <prefix>/share/quadrants/hashlink/runtime/*

The haxelib package contains Haxe interface files only.
EOF
}

log() {
  printf '[package-hashlink-user] %s\n' "$*"
}

fail() {
  printf '[package-hashlink-user] error: %s\n' "$*" >&2
  exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

prefix="$HOME/.local"
hashlink_root=""
build_dir="$repo_root/build/hashlink-user-cpu-cuda-vulkan"
out="$repo_root/build/quadrants-haxelib-user.zip"
jobs=2
install_haxelib=1
global_haxelib=0

while (($#)); do
  case "$1" in
    --prefix)
      [[ $# -ge 2 ]] || fail "--prefix requires a value"
      prefix=$2
      shift 2
      ;;
    --hashlink-root)
      [[ $# -ge 2 ]] || fail "--hashlink-root requires a value"
      hashlink_root=$2
      shift 2
      ;;
    --build-dir)
      [[ $# -ge 2 ]] || fail "--build-dir requires a value"
      build_dir=$2
      shift 2
      ;;
    --out)
      [[ $# -ge 2 ]] || fail "--out requires a value"
      out=$2
      shift 2
      ;;
    --jobs)
      [[ $# -ge 2 ]] || fail "--jobs requires a value"
      jobs=$2
      shift 2
      ;;
    --no-haxelib-install)
      install_haxelib=0
      shift
      ;;
    --global-haxelib)
      global_haxelib=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

case "$jobs" in
  ''|*[!0-9]*) fail "--jobs must be a positive integer: $jobs" ;;
esac
if (( jobs < 1 )); then
  fail "--jobs must be a positive integer: $jobs"
fi

abs_path() {
  local path=$1
  if [[ -e "$path" ]]; then
    local dir base
    dir=$(dirname -- "$path")
    base=$(basename -- "$path")
    dir=$(CDPATH= cd -- "$dir" && pwd -P)
    printf '%s/%s\n' "$dir" "$base"
  else
    local dir base
    dir=$(dirname -- "$path")
    base=$(basename -- "$path")
    mkdir -p -- "$dir"
    dir=$(CDPATH= cd -- "$dir" && pwd -P)
    printf '%s/%s\n' "$dir" "$base"
  fi
}

prefix=$(abs_path "$prefix")
if [[ -z "$hashlink_root" ]]; then
  hashlink_root="$prefix"
else
  hashlink_root=$(abs_path "$hashlink_root")
fi
build_dir=$(abs_path "$build_dir")
out=$(abs_path "$out")

if [[ ! -f "$hashlink_root/include/hl.h" && ! -f "$hashlink_root/src/hl.h" ]]; then
  fail "HashLink root must contain include/hl.h or src/hl.h: $hashlink_root"
fi
if [[ ! -f "$hashlink_root/lib/libhl.so" && ! -f "$hashlink_root/libhl.so" && ! -f "$hashlink_root/bin/libhl.dll" && ! -f "$hashlink_root/libhl.dll" ]]; then
  log "warning: libhl was not found in the usual locations under $hashlink_root"
fi

cmake_compiler_args=()
if [[ -z "${CC:-}" && -z "${CXX:-}" ]] && command -v clang-22 >/dev/null 2>&1 && command -v clang++-22 >/dev/null 2>&1; then
  cmake_compiler_args+=("-DCMAKE_C_COMPILER=$(command -v clang-22)")
  cmake_compiler_args+=("-DCMAKE_CXX_COMPILER=$(command -v clang++-22)")
fi
if [[ -z "${LLVM_DIR:-}" && -d /usr/lib/llvm-22/lib/cmake/llvm ]]; then
  cmake_compiler_args+=("-DLLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm")
fi

log "Prefix       : $prefix"
log "HashLink root: $hashlink_root"
log "Build dir    : $build_dir"
log "Haxelib zip  : $out"
log "Jobs         : $jobs"

cmake -S "$repo_root" -B "$build_dir" \
  "${cmake_compiler_args[@]}" \
  -DCMAKE_INSTALL_PREFIX="$prefix" \
  -DQD_WITH_HASHLINK=ON \
  -DQD_HASHLINK_ROOT="$hashlink_root" \
  -DQD_WITH_LLVM=ON \
  -DQD_WITH_CUDA=ON \
  -DQD_WITH_VULKAN=ON \
  -DQD_WITH_METAL=OFF \
  -DQD_WITH_AMDGPU=OFF

cmake --build "$build_dir" --target quadrants.hdll -j"$jobs"
cmake --install "$build_dir" --component hashlink_native --prefix "$prefix"

"$repo_root/scripts/package_hashlink_haxelib.sh" \
  --build-dir "$build_dir" \
  --runtime-dir "$build_dir/runtime" \
  --out "$out"

if [[ "$install_haxelib" -eq 1 ]]; then
  command -v haxelib >/dev/null 2>&1 || fail "haxelib command not found"
  if [[ "$global_haxelib" -eq 1 ]]; then
    haxelib --global install "$out" --always
  else
    haxelib install "$out" --always
  fi
fi

log "Done. Native artifacts are under $prefix; Haxe interface zip is $out"
log "Use the matching user-level HashLink executable, e.g. $prefix/bin/hl"
