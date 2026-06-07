#!/usr/bin/env bash
set -euo pipefail

root=${1:-bindings/hashlink/haxe/quadrants}
allowlist=${2:-tools/public_dynamic_allowlist.txt}

if [[ ! -f "$allowlist" ]]; then
  echo "missing allowlist: $allowlist" >&2
  exit 1
fi

mapfile -t allowed < <(grep -v '^[[:space:]]*$' "$allowlist" | grep -v '^[[:space:]]*#' || true)
mapfile -t matches < <(rg -n --no-heading \
  'public (static )?function .*Dynamic|public (static )?function .*Array<Dynamic>|public (static )?function .*hl\.NativeArray<Dynamic>|public (static )?var .*Dynamic|public final .*Array<Dynamic>|public static function .*Class<Dynamic>' \
  "$root" || true)

failures=()
for line in "${matches[@]}"; do
  ok=0
  for entry in "${allowed[@]}"; do
    if [[ "$line" == *"$entry"* ]]; then
      ok=1
      break
    fi
  done
  if [[ $ok -eq 0 ]]; then
    failures+=("$line")
  fi
done

if [[ ${#failures[@]} -ne 0 ]]; then
  printf 'unallowlisted public Dynamic surface:\n' >&2
  printf '  %s\n' "${failures[@]}" >&2
  exit 1
fi

echo "public Dynamic scan ok"
