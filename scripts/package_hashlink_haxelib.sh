#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Package the current Quadrants Haxe/HashLink build as a self-contained haxelib zip.

The package layout keeps Haxe sources under haxe/ and points haxelib's
classPath there, so native artifacts can sit next to that source root:

  haxelib.json              # classPath: "haxe"
  haxe/quadrants/*.hx
  quadrants.hdll
  runtime/*.bc
  runtime_rocm70/*.bc       # when packaging an AMDGPU build

Usage:
  scripts/package_hashlink_haxelib.sh [options]

Options:
  --build-dir DIR          CMake build directory containing quadrants.hdll and runtime/.
  --hdll FILE              Explicit quadrants.hdll/quadrants64.hdll to package.
  --runtime-dir DIR        Explicit runtime directory to package.
  --rocm-runtime-dir DIR   Explicit ROCm libdevice directory for AMDGPU packages.
  --out FILE               Output zip path. Default: build/quadrants-haxelib.zip
  --stage-dir DIR          Staging directory. Default: a temporary dir under build/.
  --keep-stage             Do not remove the staging directory after zipping.
  --allow-no-runtime       Allow packaging without runtime/*.bc files.
  --install                Run haxelib install on the produced zip after packaging.
  -h, --help               Show this help.

Auto-detection:
  If --hdll/--build-dir are omitted, the newest quadrants.hdll under build/ is used.
  The matching runtime/ directory is searched near the selected hdll/build dir.
EOF
}

log() {
  printf '[package-haxelib] %s\n' "$*"
}

fail() {
  printf '[package-haxelib] error: %s\n' "$*" >&2
  exit 1
}

script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)

build_dir=""
hdll=""
runtime_dir=""
rocm_runtime_dir=""
out="$repo_root/build/quadrants-haxelib.zip"
stage_dir=""
keep_stage=0
allow_no_runtime=0
install_after=0

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
    --out)
      [[ $# -ge 2 ]] || fail "--out requires a value"
      out=$2
      shift 2
      ;;
    --stage-dir)
      [[ $# -ge 2 ]] || fail "--stage-dir requires a value"
      stage_dir=$2
      shift 2
      ;;
    --keep-stage)
      keep_stage=1
      shift
      ;;
    --allow-no-runtime)
      allow_no_runtime=1
      shift
      ;;
    --install)
      install_after=1
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

file_mtime() {
  if stat -c '%Y' "$1" >/dev/null 2>&1; then
    stat -c '%Y' "$1"
  else
    stat -f '%m' "$1"
  fi
}

is_hdll_name() {
  local base
  base=$(basename -- "$1")
  [[ "$base" == "quadrants.hdll" || "$base" == "quadrants64.hdll" ]]
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

runtime_has_bc() {
  local dir=$1
  [[ -d "$dir" ]] || return 1
  local file
  while IFS= read -r -d '' file; do
    return 0
  done < <(find "$dir" -maxdepth 1 -type f -name '*.bc' -print0)
  return 1
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

  local isa_file
  while IFS= read -r -d '' isa_file; do
    return 0
  done < <(find "$dir" -maxdepth 1 -type f -name 'oclc_isa_version_*.bc' -print0)
  return 1
}

validate_rocm_runtime_dir() {
  local dir=$1
  [[ -d "$dir" ]] || fail "ROCm runtime directory does not exist: $dir"

  local required
  for required in "${ROCM_REQUIRED_BC_FILES[@]}"; do
    [[ -f "$dir/$required" ]] || fail "ROCm runtime directory is missing required file: $dir/$required"
  done

  if [[ -z "$(find "$dir" -maxdepth 1 -type f -name 'oclc_isa_version_*.bc' -print -quit)" ]]; then
    fail "ROCm runtime directory is missing oclc_isa_version_*.bc files: $dir"
  fi
}

copy_top_level_files() {
  local src=$1
  local dst=$2
  mkdir -p -- "$dst"
  find "$src" -maxdepth 1 -type f -exec cp -p -- {} "$dst/" \;
}

find_newest_hdll_under() {
  local root=$1
  [[ -d "$root" ]] || return 1

  local newest=""
  local newest_time=-1
  local file time
  while IFS= read -r -d '' file; do
    case "$file" in
      */_haxelib_stage_*/*|*/haxelib-package*/*|*/haxelib-stage*/*|*/haxelib-test-repo*/*)
        continue
        ;;
    esac
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
    "$dir/share/quadrants/hashlink/quadrants.hdll" \
    "$dir/share/quadrants/hashlink/quadrants64.hdll" \
    "$dir/hashlink/quadrants.hdll" \
    "$dir/hashlink/quadrants64.hdll"; do
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

  local candidates=()
  if [[ -n "$maybe_build_dir" ]]; then
    candidates+=(
      "$maybe_build_dir/runtime"
      "$maybe_build_dir/share/quadrants/runtime"
      "$maybe_build_dir/install/share/quadrants/runtime"
    )
  fi
  candidates+=(
    "$hdll_dir/runtime"
    "$hdll_dir/../runtime"
    "$hdll_dir/../../runtime"
    "$repo_root/build/runtime"
  )

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
      "${base_runtime_dir}_rocm70"
      "$(dirname -- "$base_runtime_dir")/runtime_rocm70"
    )
  fi
  if [[ -n "$maybe_build_dir" ]]; then
    candidates+=(
      "$maybe_build_dir/runtime_rocm70"
      "$maybe_build_dir/share/quadrants/runtime_rocm70"
      "$maybe_build_dir/install/share/quadrants/runtime_rocm70"
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

package_src="$repo_root/bindings/hashlink"
haxe_src="$package_src/haxe"
[[ -f "$package_src/haxelib.json" ]] || fail "missing haxelib metadata: $package_src/haxelib.json"
grep -q '"classPath"[[:space:]]*:[[:space:]]*"haxe"' "$package_src/haxelib.json" || fail "$package_src/haxelib.json must use classPath haxe"
[[ -f "$haxe_src/quadrants/Native.hx" ]] || fail "missing Haxe package source: $haxe_src/quadrants/Native.hx"

if [[ -n "$build_dir" ]]; then
  build_dir=$(abs_path "$build_dir")
  [[ -d "$build_dir" ]] || fail "build directory does not exist: $build_dir"
fi

if [[ -n "$hdll" ]]; then
  hdll=$(abs_path "$hdll")
  [[ -f "$hdll" ]] || fail "hdll does not exist: $hdll"
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
  runtime_dir=$(abs_path "$runtime_dir")
  [[ -d "$runtime_dir" ]] || fail "runtime directory does not exist: $runtime_dir"
elif runtime_dir_found=$(find_runtime_dir "$hdll" "$build_dir"); then
  runtime_dir=$runtime_dir_found
else
  runtime_dir=""
fi

if [[ -z "$runtime_dir" && "$allow_no_runtime" -ne 1 ]]; then
  fail "could not auto-detect runtime directory near $hdll; pass --runtime-dir or --allow-no-runtime"
fi

if [[ -n "$runtime_dir" && "$allow_no_runtime" -ne 1 ]]; then
  if ! runtime_has_bc "$runtime_dir"; then
    fail "runtime directory has no .bc files: $runtime_dir"
  fi
fi

out=$(abs_path "$out")
mkdir -p -- "$(dirname -- "$out")"

created_temp_stage=0
if [[ -z "$stage_dir" ]]; then
  mkdir -p -- "$repo_root/build"
  stage_dir=$(mktemp -d "$repo_root/build/_haxelib_stage_XXXXXX")
  created_temp_stage=1
else
  stage_dir=$(abs_path "$stage_dir")
  rm -rf -- "$stage_dir"
  mkdir -p -- "$stage_dir"
fi

cleanup() {
  if [[ "$keep_stage" -ne 1 && "$created_temp_stage" -eq 1 ]]; then
    rm -rf -- "$stage_dir"
  fi
}
trap cleanup EXIT

log "Package src  : $package_src"
log "Haxe sources : $haxe_src"
log "HDLL         : $hdll"
if [[ -n "$runtime_dir" ]]; then
  log "Runtime      : $runtime_dir"
else
  log "Runtime      : <none>"
fi
log "Stage        : $stage_dir"
log "Output       : $out"

cp -p -- "$package_src/haxelib.json" "$stage_dir/haxelib.json"
if [[ -f "$package_src/README.md" ]]; then
  cp -p -- "$package_src/README.md" "$stage_dir/README.md"
fi
mkdir -p -- "$stage_dir/haxe"
cp -R -- "$haxe_src/." "$stage_dir/haxe/"
cp -p -- "$hdll" "$stage_dir/$(basename -- "$hdll")"

if [[ -n "$runtime_dir" ]]; then
  copy_top_level_files "$runtime_dir" "$stage_dir/runtime"

  if [[ -f "$stage_dir/runtime/runtime_cuda.bc" && ! -f "$stage_dir/runtime/slim_libdevice.10.bc" ]]; then
    cuda_libdevice="$repo_root/external/cuda_libdevice/slim_libdevice.10.bc"
    if [[ -f "$cuda_libdevice" ]]; then
      log "Adding CUDA libdevice: $cuda_libdevice"
      cp -p -- "$cuda_libdevice" "$stage_dir/runtime/"
    else
      fail "runtime_cuda.bc is present but slim_libdevice.10.bc was not found in runtime dir or $cuda_libdevice"
    fi
  fi

  if [[ -f "$stage_dir/runtime/runtime_amdgpu.bc" ]]; then
    if [[ -n "$rocm_runtime_dir" ]]; then
      rocm_runtime_dir=$(abs_path "$rocm_runtime_dir")
    elif rocm_dir_found=$(find_rocm_runtime_dir "$runtime_dir" "$build_dir"); then
      rocm_runtime_dir=$rocm_dir_found
    else
      fail "runtime_amdgpu.bc is present but ROCm libdevice directory was not found; pass --rocm-runtime-dir"
    fi
    validate_rocm_runtime_dir "$rocm_runtime_dir"
    log "ROCm runtime : $rocm_runtime_dir"
    copy_top_level_files "$rocm_runtime_dir" "$stage_dir/runtime_rocm70"
  fi
fi

[[ -f "$stage_dir/haxelib.json" ]] || fail "staged package is missing haxelib.json"
grep -q '"classPath"[[:space:]]*:[[:space:]]*"haxe"' "$stage_dir/haxelib.json" || fail "staged haxelib.json must use classPath haxe"
[[ -d "$stage_dir/haxe/quadrants" ]] || fail "staged package is missing haxe/quadrants/ sources"
[[ -f "$stage_dir/quadrants.hdll" || -f "$stage_dir/quadrants64.hdll" ]] || fail "staged package is missing quadrants.hdll"

command -v zip >/dev/null 2>&1 || fail "zip command not found"
rm -f -- "$out"
(
  cd "$stage_dir"
  zip -qr "$out" .
)

log "Created: $out"
if [[ "$keep_stage" -eq 1 ]]; then
  log "Kept stage: $stage_dir"
fi

if [[ "$install_after" -eq 1 ]]; then
  command -v haxelib >/dev/null 2>&1 || fail "haxelib command not found"
  log "Installing with haxelib: $out"
  haxelib install "$out"
fi

log "Done. Example use:"
log "  haxelib install $out"
log "  haxe -lib quadrants -main Main -hl main.hl"
log "  hl main.hl"
