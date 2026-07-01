# Haxe API v3 plan status

Last audited: 2026-07-01 on branch `haxe-binding-v3`.

This page tracks the repository against `PLAN_breakable.md`. A phase is marked **Complete** only when API surface, compile-fail coverage, descriptor/snapshot coverage where applicable, and runtime semantic coverage are all present in the default v3 gate.

## Default v3 gate

The default HashLink v3 CTest gate is expected to include:

```text
hashlink_haxe_compile
haxe_v3_smoke
hashlink_v3_runtime_semantic
hashlink_descriptor_golden
hashlink_macro_compile_fail
hashlink_public_dynamic_scan
hashlink_package_validate
```

`tests/hashlink/hashlink_tests.hxml` is now the v3 runtime semantic suite. Pre-v3 runtime suites are not a compatibility gate.

## Phase matrix

| Phase | Status | Evidence | Remaining gaps |
| --- | --- | --- | --- |
| 0. Branch cut and deletion strategy | Complete | Branch/docs/v3 smoke/capabilities exist; old field mirror and packed primary APIs are not on the main path. | None for Phase 0. |
| 1. Public API reset | Complete | `Context.create`, `Tensor<T>`, `Field<T>`, typed `Kernel.build`/`QKernelN`, `KernelRaw` internal boundary. | None for the v3 API surface. |
| 2. Descriptor schema reset | Complete for current v3 schema | Native/Haxe descriptors use schema version 3; descriptor golden snapshots pass; `DescriptorWriter` metadata and descriptor table-builder entries are typed. | None for the current schema; add new snapshots when adding resource forms. |
| 3. Typed kernel launch and ArgEncoder | Complete | Typed wrapper launch/launchOn/launchGraph; compile-fail arity/dtype/resource tests; v3 runtime semantic suite. | None for current supported arities. |
| 4. QdArgs, Spec, data-oriented | Complete for current v3 path | `Spec<T>`, nested `@:build(QdArgs.build())`, primitive members lowered as real `Spec<T>` parameters, `@:kernel` instance methods, spec-value relaunch, and nested QdArgs descriptor snapshots are covered by v3 runtime/descriptor tests. | Broader object shapes can be added as new cases, but current DoD items are covered. |
| 5. QdStruct and compound storage | Complete for current v3 scope | `QdStruct`, `StructTensor`, `StructField` SOA, nested struct kernel load/store, Vec3 lanes, and Mat3 lane access (`m00`/`m11`) are covered by v3 runtime semantic tests; public struct schema/resource descriptors are typed. | Broader compound combinations can be added as new cases, but current vector/matrix/nested DoD items are covered. |
| 6. Tensor/Field/SNode/layout/host movement | Partial | Tensor host movement, capability queries for DLPack/external pointer interop, and direct `Field<T>` kernel params are covered by v3 smoke/semantic tests; mirror fallback path removed. | Core SNode offset placement is available, but HashLink placement bridge wiring and true DLPack/external-pointer roundtrip coverage remain pending. |
| 7. AD/Tape/custom gradient | Complete for binding scope | Reverse grad, forward grad, validation kernel launch, read-after-write validation rejection, Tape backward/withLoss/FwdMode, pause/resume/clear, registered custom-gradient replacement through typed `launchTape`, and integer/bool no-grad errors are covered by v3 runtime semantic tests. | Dynamic while-loop reverse/validation AD is a core Quadrants limitation also xfailed in Python, so it is explicitly out of Haxe binding scope rather than a remaining binding gap. |
| 8. Streams/events/graph | Partial | `launchOn`, `launchGraph`, host `launchGraphWhile`, native `launchGraphDoWhile`, `Graph.parallel`, explicit `launchTapeOn` AD/stream rejection, stream event capability errors, and gated event record/wait/sync success path are covered. | CPU stream events are a core/backend limitation and stay error-path only; supported CUDA/AMDGPU event ordering still needs backend-gated coverage. |
| 9. Algorithms/per-thread linalg | Partial | reduce/min/scan/select/sort/sort-pairs/reduce-by-key, host Linalg deterministic checks, Python-golden core cases, and a JSON-emitting benchmark are covered. | Device per-thread linalg intrinsic lowering is not available in the current HashLink kernel/native path and is skipped rather than exposed as a fake device feature. |
| 10. Sparse/Mesh/Quant | Partial | Sparse build/matvec/solver-with-explicit-fallback/mmwrite plus canonical COO/CSR import/export helpers, mesh relation/attribute traversal, quantized kernel params, quant-float placement, and fixed quant saturation golden cases are covered. | Mesh reorder/index conversion remains a bridge/native metadata gap. Quant fixed offset is removed from Haxe binding scope because core Quadrants and Python do not expose it. |
| 11. Profiler/diagnostics/release | Partial | capabilities/health/profiler trace/version self-check covered by v3 runtime semantic tests; haxelib package zip layout validation is registered as a CTest release gate. | Native memory profiler stats remain unavailable on the current backend and are skipped rather than faked. |
| 12. Cross-cutting tests | Partial | compile-fail, descriptor golden, v3 smoke, v3 runtime semantic, public-Dynamic scan, a core Python-golden JSON artifact, and a JSON-emitting HashLink benchmark exist. | Golden and benchmark coverage should grow with new deterministic features/backends. Remaining Dynamic allowlist entries are native ABI/internal replay/diagnostics boundaries. |

## Current conclusion

The v3 API has moved beyond smoke-only coverage: the main HashLink runtime suite now exercises typed kernels, nested QdArgs, QdStruct vector/matrix lanes, AD/Tape, streams/graph CPU semantics, algorithms/linalg, sparse/mesh/quant, diagnostics, profiler, and version checks.

No phase is marked Complete for behavior that is only smoke-covered or explicitly unsupported. Core-only limitations that Python also lacks (dynamic while AD, CPU stream events, quant fixed offset) are out of Haxe binding scope. Remaining Partial work is limited to bridge/Haxe wiring or supported-backend depth, especially field offset placement, mesh reorder/index conversion, device linalg, memory profiler stats, and supported-backend stream event coverage.
