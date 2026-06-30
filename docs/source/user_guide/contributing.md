# Contributing

Quadrants development now uses the CMake + Haxe/HashLink workflow.

## Build

```bash
cmake -S . -B build/dev \
  -DQD_WITH_HASHLINK=ON \
  -DQD_HASHLINK_ROOT=/path/to/hashlink \
  -DQD_WITH_LLVM=ON
cmake --build build/dev --target quadrants.hdll
```

The `quadrants.hdll` target builds the required host runtime bitcode for the current host. Add `-DQD_BUILD_HASHLINK_TESTS=ON` when you want CTest to register the Haxe/HashLink tests. Disable `QD_WITH_HASHLINK` when validating a core-only build on a machine without HashLink.

## Test

```bash
ctest --test-dir build/dev --output-on-failure
```

The HashLink CTest suite compiles the Haxe tests, runs a CPU `hl` smoke test, and checks macro compile-fail diagnostics.

## Documentation

Build the Haxe public API docs with Dox when changing public Haxe APIs:

```bash
haxelib install dox
make -C docs html
```

The docs build generates Haxe XML from `bindings/hashlink/haxe` and renders it with `haxelib run dox`; it no longer depends on Sphinx/MyST or the removed Python package.

## Haxe package development

Register the source tree directly while iterating:

```bash
haxelib dev quadrants "$PWD/bindings/hashlink"
QUADRANTS_HDLL="$PWD/build/dev/quadrants.hdll" \
QUADRANTS_RUNTIME_DIR="$PWD/build/dev/runtime" \
haxe tests/hashlink/v3/hashlink_v3_smoke.hxml -hl build/dev-v3-smoke.hl
QD_LIB_DIR="$PWD/build/dev/runtime" hl build/dev-v3-smoke.hl
```

## CI

The main Linux workflow builds `quadrants.hdll`, installs the HashLink component, registers the installed haxelib package, compiles the v3 Haxe tests, runs the v3 smoke suite, checks descriptor golden snapshots, and scans public `Dynamic` boundaries.
