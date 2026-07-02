# Haxe/HashLink API status

This page summarizes what the documented Haxe/HashLink API currently promises and how that promise is tested. It is a user-facing status page, not a migration guide or an internal implementation plan.

## Default HashLink gate

The default HashLink CTest gate is expected to include:

```text
hashlink_haxe_compile
haxe_v3_smoke
hashlink_v3_runtime_semantic
hashlink_descriptor_golden
hashlink_macro_compile_fail
hashlink_public_dynamic_scan
hashlink_package_validate
```

`tests/hashlink/hashlink_tests.hxml` is the main runtime semantic suite. Archived pre-reset runtime suites under `tests/hashlink/legacy/pre_v3/` are not a compatibility gate.

## Supported public surface

| Area | Current status | Test evidence |
| --- | --- | --- |
| Contexts and typed launch | `Context.create`, typed `Kernel.build`, typed wrappers, `Spec<T>`, and internal-only raw handles are the documented launch path. | Smoke, runtime semantic suite, compile-fail arity/dtype tests. |
| Descriptors | The native/Haxe bridge uses QDHL descriptor schema version 3 with typed type/arg/resource/spec metadata. | Descriptor golden snapshots and invalid-schema validation. |
| QdArgs / data-oriented host objects | `@:build(QdArgs.build())`, nested QdArgs primitive specialization, resource flattening, and `@:kernel` instance methods are supported. | Runtime semantic suite and descriptor snapshots. |
| QdStruct / compound storage | `QdStruct`, `StructTensor`, `StructField`, vector/matrix lanes, and nested scalar members are supported. | Runtime semantic suite and compile-fail struct diagnostics. |
| Tensors, fields, and SNodes | Tensor host movement, direct field kernel parameters, shape-based placement, physical order lowering, SNode domain offsets, and DLPack/external-pointer aliasing on supported backends are covered. | Runtime semantic suite. |
| AD / Tape / custom gradients | Reverse grad, forward grad, validation kernels, read-after-write validation rejection, Tape replay, registered custom-gradient replacement, and integer/bool no-grad errors are covered. | Runtime semantic suite and compile-fail diagnostics. |
| Streams and graph | `launchOn`, `launchGraph`, host `launchGraphWhile`, native `launchGraphDoWhile`, single-block `Graph.parallel`, explicit `Graph.sequence`, Tape/stream rejection, and capability-gated stream events are covered. | Runtime semantic suite plus optional CUDA/AMDGPU backend-depth tests. |
| Algorithms and linalg | Reduce/scan/select/sort/reduce-by-key, host linalg checks, scalar `DeviceLinalg`, and aggregate `LinalgDevice` vector/matrix-return helpers are covered. | Runtime semantic suite, Python-golden JSON, JSON benchmark smoke. |
| Sparse / mesh / quant | Sparse F32/F64 COO/CSR native bulk import/export, MatrixMarket roundtrip, explicit sparse solver fallback, mesh relation/attribute kernels, mesh index conversion, mesh save/load/reorder, quantized tensor parameters, and quant placement are covered. | Runtime semantic suite and compile-fail diagnostics. |
| Profiler / diagnostics / release | Capabilities, health checks, descriptor dumps, profiler trace events, memory-profiler typed counters, ABI/version checks, public-Dynamic scan, and haxelib package validation are covered. | Runtime semantic suite, public-Dynamic scan, package validation. |

## Explicit non-promises

The API does not promise compatibility with removed raw/legacy launch paths, old flatten/template annotations, descriptor aliases for earlier schemas, packed compound workarounds, or field-mirror fallback behavior.

Some behaviors are explicit core/backend limitations rather than Haxe binding gaps:

- reverse/validation AD for dynamic `while` loops;
- CPU stream events;
- quant fixed offset parameters.

These paths should fail clearly instead of silently falling back or pretending to be supported.

## Backend-depth status

CPU/LLVM is the default semantic gate. CUDA and AMDGPU builds can register optional backend-depth tests for stream-event ordering and multi-stream `Graph.parallel`. Those tests print a structured skip when no device/runtime is available and should pass on machines that claim backend support.

Performance is reported through JSON benchmark output and profiler APIs, but release correctness does not depend on hardware-specific timing thresholds.
