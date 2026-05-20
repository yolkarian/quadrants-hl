#!/bin/bash

set -eux

if command -v run-clang-tidy-22 >/dev/null 2>&1; then
  RUN_CLANG_TIDY=run-clang-tidy-22
  CLANG_TIDY=clang-tidy-22
elif command -v run-clang-tidy-15 >/dev/null 2>&1; then
  RUN_CLANG_TIDY=run-clang-tidy-15
  CLANG_TIDY=clang-tidy-15
else
  echo "run-clang-tidy not found" >&2
  exit 1
fi

"$RUN_CLANG_TIDY" \
  -p build/clang-tidy \
  -clang-tidy-binary "$CLANG_TIDY" \
  -header-filter="$PWD/quadrants" \
  "$PWD/quadrants"
