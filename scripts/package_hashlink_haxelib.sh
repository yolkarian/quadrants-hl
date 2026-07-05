#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Package the current Quadrants Haxe/HashLink interface as a haxelib zip.

The haxelib package contains Haxe interface code only. Install the native
HashLink extension separately, like HashLink's sdl.hdll/openal.hdll: put
quadrants.hdll on HashLink's native library path and put runtime bitcode in the
matching Quadrants runtime directory.

  haxelib.json              # classPath: "haxe"
  LICENSE
  haxe/quadrants/*.hx

Usage:
  scripts/package_hashlink_haxelib.sh [options]

Options:
  --build-dir DIR          CMake build directory containing quadrants.hdll and runtime/ for validation.
  --hdll FILE              Explicit quadrants.hdll/quadrants64.hdll to validate against.
  --runtime-dir DIR        Explicit runtime directory to validate.
  --rocm-runtime-dir DIR   Explicit ROCm libdevice directory to validate for AMDGPU builds.
  --out FILE               Output zip path. Default: build/quadrants-haxelib.zip
  --stage-dir DIR          Staging directory. Default: a temporary dir under build/.
  --keep-stage             Do not remove the staging directory after zipping.
  --allow-no-runtime       Allow native validation without runtime/runtime_*.bc files.
  --skip-native-symbol-check
                            Do not verify that Native.hx @:hlNative functions are exported by the hdll.
  --install                Run haxelib install on the produced zip after packaging.
  -h, --help               Show this help.

Auto-detection:
  If native validation is enabled and --hdll/--build-dir are omitted, the newest
  quadrants.hdll under build/ is used. The matching runtime/ directory is
  searched near the selected hdll/build dir.
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
skip_native_symbol_check=0
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
    --skip-native-symbol-check)
      skip_native_symbol_check=1
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

existing_abs_path() {
  local path=$1
  [[ -e "$path" ]] || return 1
  local dir base
  dir=$(dirname -- "$path")
  base=$(basename -- "$path")
  dir=$(CDPATH= cd -- "$dir" && pwd -P)
  printf '%s/%s\n' "$dir" "$base"
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

  if ! runtime_has_quadrants_bc "$dir"; then
    fail "runtime directory has no Quadrants runtime_*.bc files: $dir"
  fi

  if ! runtime_has_host_bc "$dir"; then
    fail "runtime directory is missing host runtime bitcode (runtime_x64.bc, runtime_arm64.bc, or runtime_x86.bc): $dir"
  fi

  if [[ -f "$dir/runtime_cuda.bc" && ! -f "$dir/slim_libdevice.10.bc" && ! -f "$repo_root/external/cuda_libdevice/slim_libdevice.10.bc" ]]; then
    fail "runtime directory has runtime_cuda.bc but is missing slim_libdevice.10.bc: $dir"
  fi
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

validate_staged_package_layout() {
  local dir=$1
  [[ -f "$dir/haxelib.json" ]] || fail "staged package is missing haxelib.json"
  grep -q '"classPath"[[:space:]]*:[[:space:]]*"haxe"' "$dir/haxelib.json" || fail "staged haxelib.json must use classPath haxe"
  grep -q '"version"[[:space:]]*:' "$dir/haxelib.json" || fail "staged haxelib.json is missing version"
  [[ -d "$dir/haxe/quadrants" ]] || fail "staged package is missing haxe/quadrants/ sources"
  [[ -f "$dir/haxe/quadrants/Native.hx" ]] || fail "staged package is missing haxe/quadrants/Native.hx"
  [[ -f "$dir/haxe/quadrants/VersionInfo.hx" ]] || fail "staged package is missing haxe/quadrants/VersionInfo.hx"

  local hx_count
  hx_count=$(find "$dir/haxe/quadrants" -type f -name '*.hx' | wc -l | tr -d '[:space:]')
  [[ "$hx_count" != "0" ]] || fail "staged package contains no Haxe source files"

  local stray
  stray=$(find "$dir" -maxdepth 2 -type f \( -name 'PLAN*.md' -o -name 'DIFF.md' -o -name '*.patch' \) -print -quit)
  [[ -z "$stray" ]] || fail "staged package contains non-release planning/diff file: $stray"

}

validate_zip_layout() {
  local zip_file=$1
  if ! command -v unzip >/dev/null 2>&1; then
    log "Zip layout: skipped (unzip command not found)"
    return 0
  fi

  local listing
  listing=$(mktemp)
  unzip -Z1 "$zip_file" > "$listing" || {
    rm -f -- "$listing"
    fail "could not inspect created zip: $zip_file"
  }

  grep -Fxq "haxelib.json" "$listing" || fail "created zip is missing haxelib.json"
  grep -Fxq "haxe/quadrants/Native.hx" "$listing" || fail "created zip is missing haxe/quadrants/Native.hx"
  if grep -Eq '(^|/)(PLAN[^/]*\.md|DIFF\.md|.*\.patch)$' "$listing"; then
    fail "created zip contains planning/diff files"
  fi
  rm -f -- "$listing"
  log "Zip layout: ok"
}

native_prim_names() {
  local native_hx=$1
  sed -n 's/.*@:hlNative([[:space:]]*"[^"]*"[[:space:]]*,[[:space:]]*"\([^"]*\)".*/\1/p' "$native_hx" | sort -u
}

dynamic_symbol_names() {
  local binary=$1

  if command -v nm >/dev/null 2>&1; then
    if nm -D --defined-only "$binary" >/dev/null 2>&1; then
      nm -D --defined-only "$binary" | awk 'NF {print $NF}' | sed 's/^_//; s/@.*//' | sort -u
      return 0
    fi
    if nm -gU "$binary" >/dev/null 2>&1; then
      nm -gU "$binary" | awk 'NF {print $NF}' | sed 's/^_//; s/@.*//' | sort -u
      return 0
    fi
  fi

  if command -v objdump >/dev/null 2>&1 && objdump -T "$binary" >/dev/null 2>&1; then
    objdump -T "$binary" | awk 'NF {print $NF}' | sed 's/^_//; s/@.*//' | sort -u
    return 0
  fi

  return 1
}

validate_native_symbols() {
  local hdll_file=$1
  local native_hx=$2

  if [[ "$skip_native_symbol_check" -eq 1 ]]; then
    log "Native symbols: skipped"
    return 0
  fi

  local symbol_names
  symbol_names=$(mktemp)
  if ! dynamic_symbol_names "$hdll_file" > "$symbol_names"; then
    rm -f -- "$symbol_names"
    log "Native symbols: skipped (could not inspect exported symbols; install nm or objdump to enable this check)"
    return 0
  fi

  local missing=()
  local prim_count=0
  local prim
  while IFS= read -r prim; do
    [[ -n "$prim" ]] || continue
    ((prim_count += 1))
    if ! grep -Fxq "hlp_$prim" "$symbol_names" && ! grep -Fxq "quadrants_$prim" "$symbol_names"; then
      missing+=("$prim")
    fi
  done < <(native_prim_names "$native_hx")
  rm -f -- "$symbol_names"

  if (( prim_count == 0 )); then
    fail "could not find @:hlNative declarations in $native_hx"
  fi

  if (( ${#missing[@]} > 0 )); then
    local shown=""
    local i
    for ((i = 0; i < ${#missing[@]} && i < 12; i++)); do
      if [[ -n "$shown" ]]; then
        shown+=", "
      fi
      shown+="${missing[$i]}"
    done
    if (( ${#missing[@]} > 12 )); then
      shown+=", ..."
    fi
    fail "selected hdll is missing ${#missing[@]} native symbol(s) required by current Haxe sources: $shown. Rebuild quadrants.hdll or pass --skip-native-symbol-check to bypass."
  fi

  log "Native symbols: ok"
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

  local candidates=(
    "$hdll_dir/runtime"
    "$hdll_dir/../runtime"
    "$hdll_dir/../../runtime"
  )
  if [[ -n "$maybe_build_dir" ]]; then
    candidates+=(
      "$maybe_build_dir/runtime"
      "$maybe_build_dir/share/quadrants/hashlink/runtime"
      "$maybe_build_dir/share/quadrants/runtime"
      "$maybe_build_dir/install/share/quadrants/hashlink/runtime"
      "$maybe_build_dir/install/share/quadrants/runtime"
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
elif [[ "$skip_native_symbol_check" -eq 0 ]]; then
  if [[ -f "$PWD/quadrants.hdll" || -f "$PWD/quadrants64.hdll" ]]; then
    if [[ -f "$PWD/quadrants.hdll" ]]; then
      hdll=$(abs_path "$PWD/quadrants.hdll")
    else
      hdll=$(abs_path "$PWD/quadrants64.hdll")
    fi
    build_dir=$(dirname -- "$hdll")
  else
    hdll=$(find_newest_hdll_under "$repo_root/build") || fail "could not auto-detect quadrants.hdll under $repo_root/build; pass --build-dir/--hdll or --skip-native-symbol-check"
    hdll=$(abs_path "$hdll")
    build_dir=$(dirname -- "$hdll")
  fi
else
  hdll=""
fi

if [[ -z "$build_dir" && -n "$hdll" ]]; then
  build_dir=$(dirname -- "$hdll")
fi

if [[ -n "$runtime_dir" ]]; then
  [[ -d "$runtime_dir" ]] || fail "runtime directory does not exist: $runtime_dir"
  runtime_dir=$(existing_abs_path "$runtime_dir")
elif [[ -n "$hdll" ]] && runtime_dir_found=$(find_runtime_dir "$hdll" "$build_dir"); then
  runtime_dir=$runtime_dir_found
else
  runtime_dir=""
fi

if [[ -z "$runtime_dir" && "$allow_no_runtime" -ne 1 && -n "$hdll" ]]; then
  fail "could not auto-detect runtime directory near $hdll; pass --runtime-dir or --allow-no-runtime"
fi

if [[ -n "$runtime_dir" && "$allow_no_runtime" -ne 1 ]]; then
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

if [[ -n "$hdll" ]]; then
  validate_native_symbols "$hdll" "$haxe_src/quadrants/Native.hx"
else
  log "Native symbols: skipped (no hdll selected)"
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
if [[ -n "$hdll" ]]; then
  log "HDLL check   : $hdll"
else
  log "HDLL check   : <none>"
fi
if [[ -n "$runtime_dir" ]]; then
  log "Runtime check: $runtime_dir"
else
  log "Runtime check: <none>"
fi
if [[ -n "$rocm_runtime_dir" ]]; then
  log "ROCm check   : $rocm_runtime_dir"
fi
log "Stage        : $stage_dir"
log "Output       : $out"

cp -p -- "$package_src/haxelib.json" "$stage_dir/haxelib.json"
if [[ -f "$package_src/README.md" ]]; then
  cp -p -- "$package_src/README.md" "$stage_dir/README.md"
fi
if [[ -f "$repo_root/LICENSE" ]]; then
  cp -p -- "$repo_root/LICENSE" "$stage_dir/LICENSE"
fi
mkdir -p -- "$stage_dir/haxe"
cp -R -- "$haxe_src/." "$stage_dir/haxe/"

validate_staged_package_layout "$stage_dir"

command -v zip >/dev/null 2>&1 || fail "zip command not found"
rm -f -- "$out"
(
  cd "$stage_dir"
  zip -qr "$out" .
)
validate_zip_layout "$out"

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
log "  # install/copy quadrants.hdll and runtime bitcode to the HashLink native setup first"
log "  haxe -lib quadrants -main Main -hl main.hl"
log "  hl main.hl"
