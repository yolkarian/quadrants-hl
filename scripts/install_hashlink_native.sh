#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Install Quadrants HashLink native artifacts separately from the haxelib package.

This installs quadrants.hdll and runtime bitcode in the same style as HashLink's
native extensions such as sdl.hdll/openal.hdll. The Haxe interface is packaged
separately with scripts/package_hashlink_haxelib.sh.

Modes:
  --hashlink-dir DIR       User-level/dev install: copy quadrants.hdll next to
                           DIR/hl and runtime files under DIR/quadrants/runtime.
  --prefix DIR             Prefix install: copy quadrants.hdll to DIR/lib and
                           runtime files under DIR/share/quadrants/hashlink/runtime.
                           Use a user prefix such as $HOME/.local for no-sudo setup,
                           and run the matching DIR/bin/hl when relying on rpath.

Options:
  --build-dir DIR          CMake build directory containing quadrants.hdll and runtime/.
  --hdll FILE              Explicit quadrants.hdll/quadrants64.hdll to install.
  --runtime-dir DIR        Explicit runtime directory to install.
  --rocm-runtime-dir DIR   Explicit ROCm libdevice directory for AMDGPU installs.
  --lib-dir DIR            Override prefix lib directory. Relative paths are under --prefix.
  --allow-no-runtime       Allow installing only quadrants.hdll.
  -h, --help               Show this help.

Examples:
  scripts/install_hashlink_native.sh --build-dir build/hashlink --hashlink-dir ../hashlink
  scripts/install_hashlink_native.sh --build-dir build/hashlink --prefix "$HOME/.local"
EOF
}

log() {
  printf '[install-hashlink-native] %s\n' "$*"
}

fail() {
  printf '[install-hashlink-native] error: %s\n' "$*" >&2
  exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

build_dir=""
hdll=""
runtime_dir=""
rocm_runtime_dir=""
hashlink_dir=""
prefix=""
lib_dir=""
allow_no_runtime=0

while (($#)); do
  case "$1" in
    --build-dir)
      [[ $# -ge 2 ]] || fail "--build-dir requires a value"
      build_dir=$2
      shift 2
      ;;
    --hdll)
      [[ $# -ge 2 ]] || fail "--hdll requires a value"
      hdll=$2
      shift 2
      ;;
    --runtime-dir)
      [[ $# -ge 2 ]] || fail "--runtime-dir requires a value"
      runtime_dir=$2
      shift 2
      ;;
    --rocm-runtime-dir)
      [[ $# -ge 2 ]] || fail "--rocm-runtime-dir requires a value"
      rocm_runtime_dir=$2
      shift 2
      ;;
    --hashlink-dir)
      [[ $# -ge 2 ]] || fail "--hashlink-dir requires a value"
      hashlink_dir=$2
      shift 2
      ;;
    --prefix)
      [[ $# -ge 2 ]] || fail "--prefix requires a value"
      prefix=$2
      shift 2
      ;;
    --lib-dir)
      [[ $# -ge 2 ]] || fail "--lib-dir requires a value"
      lib_dir=$2
      shift 2
      ;;
    --allow-no-runtime)
      allow_no_runtime=1
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

existing_abs_path() {
  local path=$1
  [[ -e "$path" ]] || return 1
  local dir base
  dir=$(dirname -- "$path")
  base=$(basename -- "$path")
  dir=$(CDPATH= cd -- "$dir" && pwd -P)
  printf '%s/%s\n' "$dir" "$base"
}

is_hdll_name() {
  local base
  base=$(basename -- "$1")
  [[ "$base" == "quadrants.hdll" || "$base" == "quadrants64.hdll" ]]
}

file_mtime() {
  if stat -c '%Y' "$1" >/dev/null 2>&1; then
    stat -c '%Y' "$1"
  else
    stat -f '%m' "$1"
  fi
}

runtime_has_files() {
  local dir=$1
  [[ -d "$dir" ]] || return 1
  local file
  while IFS= read -r -d '' file; do
    return 0
  done < <(find "$dir" -maxdepth 1 -type f -print0)
  return 1
}

runtime_has_quadrants_bc() {
  local dir=$1
  [[ -d "$dir" ]] || return 1
  local file
  while IFS= read -r -d '' file; do
    return 0
  done < <(find "$dir" -maxdepth 1 -type f -name 'runtime_*.bc' -print0)
  return 1
}

runtime_has_host_bc() {
  local dir=$1
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/runtime_x64.bc" || -f "$dir/runtime_arm64.bc" || -f "$dir/runtime_x86.bc" ]]
}

validate_runtime_dir() {
  local dir=$1
  [[ -d "$dir" ]] || fail "runtime directory does not exist: $dir"
  runtime_has_quadrants_bc "$dir" || fail "runtime directory has no Quadrants runtime_*.bc files: $dir"
  runtime_has_host_bc "$dir" || fail "runtime directory is missing host runtime bitcode: $dir"
}

readonly ROCM_REQUIRED_BC_FILES=(
  ocml.bc
  oclc_wavefrontsize64_on.bc
  ockl.bc
  oclc_abi_version_400.bc
  oclc_correctly_rounded_sqrt_off.bc
  oclc_daz_opt_off.bc
  oclc_finite_only_off.bc
  oclc_unsafe_math_off.bc
  opencl.bc
)

rocm_runtime_has_required_bc() {
  local dir=$1
  [[ -d "$dir" ]] || return 1
  local required
  for required in "${ROCM_REQUIRED_BC_FILES[@]}"; do
    [[ -f "$dir/$required" ]] || return 1
  done
  [[ -n "$(find "$dir" -maxdepth 1 -type f -name 'oclc_isa_version_*.bc' -print -quit)" ]]
}

validate_rocm_runtime_dir() {
  local dir=$1
  [[ -d "$dir" ]] || fail "ROCm runtime directory does not exist: $dir"
  rocm_runtime_has_required_bc "$dir" || fail "ROCm runtime directory is missing required ROCm bitcode: $dir"
}

find_newest_hdll_under() {
  local root=$1
  [[ -d "$root" ]] || return 1
  local newest=""
  local newest_time=-1
  local file time
  while IFS= read -r -d '' file; do
    time=$(file_mtime "$file")
    if (( time > newest_time )); then
      newest_time=$time
      newest=$file
    fi
  done < <(find "$root" -type f \( -name 'quadrants.hdll' -o -name 'quadrants64.hdll' \) -print0)
  [[ -n "$newest" ]] || return 1
  printf '%s\n' "$newest"
}

find_hdll_in_build_dir() {
  local dir=$1
  local candidate
  for candidate in \
    "$dir/quadrants.hdll" \
    "$dir/quadrants64.hdll" \
    "$dir/lib/quadrants.hdll" \
    "$dir/lib/quadrants64.hdll" \
    "$dir/share/quadrants/hashlink/quadrants.hdll" \
    "$dir/share/quadrants/hashlink/quadrants64.hdll"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  find_newest_hdll_under "$dir"
}

find_runtime_dir() {
  local hdll_file=$1
  local maybe_build_dir=$2
  local hdll_dir
  hdll_dir=$(dirname -- "$hdll_file")
  local candidates=(
    "$hdll_dir/runtime"
    "$hdll_dir/quadrants/runtime"
    "$hdll_dir/../runtime"
  )
  if [[ -n "$maybe_build_dir" ]]; then
    candidates+=(
      "$maybe_build_dir/runtime"
      "$maybe_build_dir/share/quadrants/hashlink/runtime"
      "$maybe_build_dir/share/quadrants/runtime"
      "$maybe_build_dir/install/share/quadrants/hashlink/runtime"
    )
  fi
  candidates+=("$repo_root/build/runtime")

  local candidate
  for candidate in "${candidates[@]}"; do
    if runtime_has_files "$candidate"; then
      abs_path "$candidate"
      return 0
    fi
  done
  return 1
}

find_rocm_runtime_dir() {
  local base_runtime_dir=$1
  local maybe_build_dir=$2
  local candidates=()
  if [[ -n "$base_runtime_dir" ]]; then
    candidates+=(
      "$(dirname -- "$base_runtime_dir")/runtime_rocm70"
      "${base_runtime_dir}_rocm70"
    )
  fi
  if [[ -n "$maybe_build_dir" ]]; then
    candidates+=(
      "$maybe_build_dir/runtime_rocm70"
      "$maybe_build_dir/share/quadrants/hashlink/runtime_rocm70"
      "$maybe_build_dir/share/quadrants/runtime_rocm70"
      "$maybe_build_dir/install/share/quadrants/hashlink/runtime_rocm70"
    )
  fi
  candidates+=("$repo_root/external/amdgpu_libdevice_rocm70")

  local candidate
  for candidate in "${candidates[@]}"; do
    if rocm_runtime_has_required_bc "$candidate"; then
      abs_path "$candidate"
      return 0
    fi
  done
  return 1
}

copy_top_level_files() {
  local src=$1
  local dst=$2
  mkdir -p -- "$dst"
  find "$src" -maxdepth 1 -type f -exec install -m 644 -- {} "$dst/" \;
}

if [[ -n "$hashlink_dir" && -n "$prefix" ]]; then
  fail "choose only one install mode: --hashlink-dir or --prefix"
fi
if [[ -z "$hashlink_dir" && -z "$prefix" ]]; then
  fail "choose an install mode: --hashlink-dir or --prefix"
fi

if [[ -n "$build_dir" ]]; then
  [[ -d "$build_dir" ]] || fail "build directory does not exist: $build_dir"
  build_dir=$(existing_abs_path "$build_dir")
fi

if [[ -n "$hdll" ]]; then
  [[ -f "$hdll" ]] || fail "hdll does not exist: $hdll"
  hdll=$(existing_abs_path "$hdll")
  is_hdll_name "$hdll" || fail "--hdll must point to quadrants.hdll or quadrants64.hdll: $hdll"
elif [[ -n "$build_dir" ]]; then
  hdll=$(find_hdll_in_build_dir "$build_dir") || fail "could not find quadrants.hdll in build dir: $build_dir"
  hdll=$(abs_path "$hdll")
elif [[ -f "$PWD/quadrants.hdll" || -f "$PWD/quadrants64.hdll" ]]; then
  if [[ -f "$PWD/quadrants.hdll" ]]; then
    hdll=$(abs_path "$PWD/quadrants.hdll")
  else
    hdll=$(abs_path "$PWD/quadrants64.hdll")
  fi
  build_dir=$(dirname -- "$hdll")
else
  hdll=$(find_newest_hdll_under "$repo_root/build") || fail "could not auto-detect quadrants.hdll under $repo_root/build; pass --build-dir or --hdll"
  hdll=$(abs_path "$hdll")
  build_dir=$(dirname -- "$hdll")
fi

if [[ -z "$build_dir" ]]; then
  build_dir=$(dirname -- "$hdll")
fi

if [[ -n "$runtime_dir" ]]; then
  [[ -d "$runtime_dir" ]] || fail "runtime directory does not exist: $runtime_dir"
  runtime_dir=$(existing_abs_path "$runtime_dir")
elif runtime_dir_found=$(find_runtime_dir "$hdll" "$build_dir"); then
  runtime_dir=$runtime_dir_found
else
  runtime_dir=""
fi

if [[ -z "$runtime_dir" && "$allow_no_runtime" -ne 1 ]]; then
  fail "could not auto-detect runtime directory near $hdll; pass --runtime-dir or --allow-no-runtime"
fi
if [[ -n "$runtime_dir" ]]; then
  validate_runtime_dir "$runtime_dir"
fi

if [[ -n "$runtime_dir" && -f "$runtime_dir/runtime_amdgpu.bc" ]]; then
  if [[ -n "$rocm_runtime_dir" ]]; then
    [[ -d "$rocm_runtime_dir" ]] || fail "ROCm runtime directory does not exist: $rocm_runtime_dir"
    rocm_runtime_dir=$(existing_abs_path "$rocm_runtime_dir")
  elif rocm_dir_found=$(find_rocm_runtime_dir "$runtime_dir" "$build_dir"); then
    rocm_runtime_dir=$rocm_dir_found
  else
    fail "runtime_amdgpu.bc is present but ROCm libdevice directory was not found; pass --rocm-runtime-dir"
  fi
  validate_rocm_runtime_dir "$rocm_runtime_dir"
fi

if [[ -n "$hashlink_dir" ]]; then
  hashlink_dir=$(abs_path "$hashlink_dir")
  [[ -f "$hashlink_dir/hl" || -f "$hashlink_dir/hl.exe" ]] || log "warning: no hl executable found in $hashlink_dir"
  hdll_dest="$hashlink_dir/$(basename -- "$hdll")"
  runtime_dest="$hashlink_dir/quadrants/runtime"
else
  prefix=$(abs_path "$prefix")
  if [[ -n "$lib_dir" ]]; then
    case "$lib_dir" in
      /*) ;;
      *) lib_dir="$prefix/$lib_dir" ;;
    esac
  else
    lib_dir="$prefix/lib"
  fi
  lib_dir=$(abs_path "$lib_dir")
  hdll_dest="$lib_dir/$(basename -- "$hdll")"
  runtime_dest="$prefix/share/quadrants/hashlink/runtime"
fi

mkdir -p -- "$(dirname -- "$hdll_dest")"
install -m 755 -- "$hdll" "$hdll_dest"
log "Installed HDLL: $hdll_dest"

if [[ -n "$runtime_dir" ]]; then
  copy_top_level_files "$runtime_dir" "$runtime_dest"
  if [[ -f "$runtime_dir/runtime_cuda.bc" && ! -f "$runtime_dest/slim_libdevice.10.bc" ]]; then
    cuda_libdevice="$repo_root/external/cuda_libdevice/slim_libdevice.10.bc"
    [[ -f "$cuda_libdevice" ]] || fail "runtime_cuda.bc requires slim_libdevice.10.bc, but $cuda_libdevice was not found"
    install -m 644 -- "$cuda_libdevice" "$runtime_dest/"
  fi
  log "Installed runtime: $runtime_dest"
fi

if [[ -n "$rocm_runtime_dir" ]]; then
  rocm_dest="${runtime_dest}_rocm70"
  copy_top_level_files "$rocm_runtime_dir" "$rocm_dest"
  log "Installed ROCm runtime: $rocm_dest"
fi

log "Done. Install the Haxe interface separately with scripts/package_hashlink_haxelib.sh."
if [[ -n "$prefix" ]]; then
  log "Use the matching HashLink executable from this prefix when relying on rpath: $prefix/bin/hl"
else
  log "Use the HashLink executable from this directory: $hashlink_dir/hl"
fi
