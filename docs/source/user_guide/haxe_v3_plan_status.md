# Haxe API v3 plan status

Last audited: 2026-06-17 on branch `haxe-binding-v3`.

This page tracks the repository against `PLAN_breakable.md`. It is a release-readiness status page, not a promise that every planned phase is complete.

## Test coverage checked

The default HashLink v3 CTest suite passes in the current CPU build:

```text
ctest --test-dir build/hashlink-cpu-clang --output-on-failure
# hashlink_haxe_compile, haxe_v3_smoke, hashlink_descriptor_golden,
# hashlink_macro_compile_fail, hashlink_public_dynamic_scan: passed
```

Only v3 HashLink tests are registered by the default CTest integration; pre-v3 runtime suites are no longer exposed as a CMake compatibility gate.

## Phase matrix

| Phase | Status | Implemented in-tree | Remaining gaps | Main coverage/docs |
| --- | --- | --- | --- | --- |
| 0. Branch cut and deletion strategy | Complete | Branch is `haxe-binding-v3`; haxelib version is `0.3.0-breaking`; v3 docs, v3 smoke, descriptor golden, compile-fail, and public-Dynamic scan tests are the only default CTest gate. Pre-v3 runtime suite registration and legacy typed/flatten docs have been removed from the main docs path. | No Phase 0 blocker remains. | `tests/hashlink/v3/Smoke.hx`, `tests/hashlink/descriptor/DescriptorGoldenSnapshot.hx`, `haxe_api_v3.md`, `haxe_kernel_v3.md`, `haxe_migration_v2_to_v3.md`, `haxe_capabilities.md`. |
| 1. Public API reset | Complete | `Context.create(...)`, `Tensor<T>`, `Field<T>`, `LayoutPolicy`, `Layout`, typed `Kernel.build(...)` wrappers, private arg writers, and typed `QKernelN` launch are the public path. `Kernel` is now a macro-only facade; runtime `Kernel.fromRaw/fromDescriptor` was removed, typed kernels expose descriptor metadata directly, and `ContextOptions` fluent/builder constructors were removed in favor of the single `Context.create({...})` options object. | No Phase 1 blocker remains. | v3 smoke; compile-fail dtype/arity/resource tests; `dynamic_boundaries.md`. |
| 2. Descriptor schema reset | Complete | Binary QDHL descriptors use only version `3`; descriptors include native-parsed TypeTable, ArgTable, ResourceTable, StructTable, and SpecTable sections. Native validation/lowering and Haxe launch decoding canonicalize parameter/resource/spec lowering from these tables before compiling or launching the KernelIr body; `DescriptorV2` and the old descriptor docs path have been removed. JSON metadata has matching header/type/arg/resource/spec/capability fields, and `Diagnostics.dumpDescriptor(...)` exposes the parsed canonical tables. | No Phase 2 blocker remains; add new golden snapshots only when introducing new resource forms in later phases. | `TestDescriptorSnapshot.hx`, `tests/hashlink/descriptor/DescriptorGoldenSnapshot.hx`, `hashlink_descriptor_golden`; `haxe_descriptor.md`. |
| 3. Typed kernel launch and ArgEncoder | Complete | `Kernel.build` infers `QKernel0`...`QKernel12`; generated launch closures call specialized `ArgWriter` methods; compile-fail tests cover arity/dtype/resource mismatches; `Spec<T>` values are split from runtime launch args before crossing into native specialization; raw dynamic/buffer launch methods are hidden bridge internals. | No Phase 3 blocker remains. | `TestTypedKernelRuntime.hx`, compile-fail cases, v3 smoke. |
| 4. QdArgs, Spec, data-oriented | Complete | `@:build(quadrants.macro.QdArgs.build())`, resource flattening, primitive/spec classification metadata, nested QdArgs support, `@:kernel` instance forwarders, descriptor SpecTable entries, and launch-time native specialization/cache keys for `Spec<T>` exist. Legacy `@:qdFlatten`, `@:qdDataOriented`, `Template.build`, `TemplateDType`, `@:template`, and `@:param` paths were removed. | No Phase 4 blocker remains. | v3 smoke, `QdArgs*`/`Spec*` compile-fail cases, `haxe_kernel_v3.md`. |
| 5. QdStruct and compound storage | Complete | `@:build(quadrants.macro.QdStruct.build())` validates POD fields; `StructTensor<S>` and `StructField<S>` allocate member resources; `StructTensor<S>` kernel parameters support load-copy-store (`var p = particles[i]; ...; particles[i] = p`) and direct scalar/vector/matrix/nested member load/store through descriptor-expanded member resources and StructTable metadata. Packed vector/matrix/struct workaround APIs and `StructValue*` host shims were removed. | No Phase 5 blocker remains. | v3 smoke covers scalar, vector-lane, and nested struct kernel load/store; QdStruct/StructTensor compile-fail cases. |
| 6. Tensor/Field/SNode/layout/host movement | Complete | Tensor read/write/copy/fill/bytes/DLPack/external-pointer methods exist; direct `Field<T>` kernel params pass SNode ids; dense/pointer/bitmasked/dynamic/quantArray placement paths exist. Field mirror fallback diagnostics, launch-time sync hooks, `dynamic_`, untyped `placeMany`, and heterogeneous FieldTree lazy helpers were removed. | Layout/order/offset validation is descriptor-level for supported placement paths; add new validation snapshots only when adding new layout policies. | v3 smoke; SNode/tensor tests; `kernel_language.md`, `haxe_api_v3.md`. |
| 7. AD/Tape/custom gradient | Complete | `grad()`, `forwardGrad()`, `validationKernel()`, `Tape.withLoss`, typed `launchTape(...)`, and `CustomGradient.register(...)` exist. Public `Tape.launch(...Dynamic)` was removed; Tape's heterogeneous replay storage is internal-only, and custom-gradient forward/backward/forwardGrad/validation kernels are schema-validated at registration. | No Phase 7 blocker remains. | AD/Tape tests; `haxe_kernel_v3.md`. |
| 8. Streams/events/graph | Complete | `Context.createStream`, `StreamEvent`, typed `launchOn`, typed graph control tensors on `QKernelN`, and `Graph.parallel` host composition exist. Stream-parallel marker APIs were removed; `graph.nativeDoWhile` is capability-gated and typed `launchGraphDoWhile` fails clearly when unsupported instead of falling back to host loops. | No Phase 8 blocker remains. | Stream/graph tests; `haxe_kernel_v3.md`. |
| 9. Algorithms/per-thread linalg | Complete | `Algorithms.reduceAdd/reduceMin/exclusiveScanAdd/select/radixSort/radixSortPairs/reduceByKeyAdd`, `Scratch.create/reserve/clear`, and host semantic `Linalg.svd2/svd3/symEig2/symEig3/eig2/polar2/polar3/solve2/solve3/makeSpd` exist. Algorithm calls validate context/scratch ownership; unsupported native performance paths are optimization work, not a v3 API blocker. | No Phase 9 blocker remains. | v3 smoke covers `Scratch`, `reduceAdd`, `solve2`, `symEig2`, and `svd2`; algorithms/linalg tests cover current supported paths. |
| 10. Sparse/Mesh/Quant | Complete | Sparse F32/F64 host-reference matrices/solvers with strict COO/CSR tensor validation, typed host mesh handles, static mesh-for lowering, mesh relation/attribute kernel access through canonical mesh resource descriptors, native SNode-backed mesh topology handles, field-backed mesh attributes, quant descriptors, int/fixed `quantArray(...).placeQuant(...)`, native `bitStruct(...).placeQuant(...)`, quant-float SNode placement, `QuantizedF32Tensor` kernel read/write parameters, sparse `buildFromTensor`, MatrixMarket write, and host matvec helpers exist. Native sparse backend and mesh index-conversion are explicit capabilities instead of silent fallback paths. | No Phase 10 blocker remains. | v3 smoke covers sparse bridge, mesh relation/attribute native topology, quantized kernel params, and quant-float bitStruct placement; sparse/mesh/quant runtime and compile-fail tests; `haxe_api_v3.md`, `haxe_capabilities.md`. |
| 11. Profiler/diagnostics/release | Complete | Profiler query APIs, scoped trace-event recording, diagnostics dumps, coverage hooks, native/Haxe ABI self-check, version constants, haxelib metadata, explicit memory-profiler capability/status probes, and the haxelib packaging script exist. The packaging script validates staged source/native/runtime layout and final zip contents. | No Phase 11 blocker remains. | Profiler/diagnostics/release tests; `haxe_release_readiness.md`, `dynamic_boundaries.md`. |

## Current conclusion

The repository now implements all v3 plan phases in the default HashLink path. Backend-specific accelerators that are not available in the current native build are represented as explicit capabilities or validation errors rather than compatibility shims or silent fallbacks.

For release gating, treat these as the minimum checks:

1. `ctest --test-dir build/hashlink-cpu-clang --output-on-failure`
2. `tools/check_public_dynamic.sh`
3. `make -C docs xml`

Before marking a phase complete, add or refresh all three coverage classes from the plan where applicable: compile-fail tests, normalized descriptor snapshots, and runtime semantic tests, plus user-guide documentation for the public API or explicit unsupported boundary.
