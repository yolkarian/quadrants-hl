# Haxe API v3 plan status

Last audited: 2026-06-17 on branch `haxe-binding-v3`.

This page tracks the repository against `PLAN_breakable.md`. It is a release-readiness status page, not a promise that every planned phase is complete.

## Test coverage checked

The default HashLink v3 CTest suite passes in the current CPU build:

```text
ctest --test-dir build/hashlink-cpu-clang --output-on-failure
# hashlink_haxe_compile, haxe_v3_smoke, hashlink_macro_compile_fail,
# hashlink_public_dynamic_scan: passed
```

Only v3 HashLink tests are registered by the default CTest integration; pre-v3 runtime suites are no longer exposed as a CMake compatibility gate.

## Phase matrix

| Phase | Status | Implemented in-tree | Remaining gaps | Main coverage/docs |
| --- | --- | --- | --- | --- |
| 0. Branch cut and deletion strategy | Complete | Branch is `haxe-binding-v3`; haxelib version is `0.3.0-breaking`; v3 docs, v3 smoke, descriptor golden, compile-fail, and public-Dynamic scan tests are the only default CTest gate. Pre-v3 runtime suite registration and legacy typed/flatten docs have been removed from the main docs path. | No Phase 0 blocker remains. | `tests/hashlink/v3/Smoke.hx`, `tests/hashlink/descriptor/DescriptorGoldenSnapshot.hx`, `haxe_api_v3.md`, `haxe_kernel_v3.md`, `haxe_migration_v2_to_v3.md`, `haxe_capabilities.md`. |
| 1. Public API reset | Complete | `Context.create(...)`, `Tensor<T>`, `Field<T>`, `LayoutPolicy`, `Layout`, typed `Kernel.build(...)` wrappers, private arg writers, and typed `QKernelN` launch are the public path. `Kernel` is now a macro-only facade; runtime `Kernel.fromRaw/fromDescriptor` was removed, typed kernels expose descriptor metadata directly, and `ContextOptions` fluent/builder constructors were removed in favor of the single `Context.create({...})` options object. | No Phase 1 blocker remains. | v3 smoke; compile-fail dtype/arity/resource tests; `dynamic_boundaries.md`. |
| 2. Descriptor schema reset | Complete | Binary QDHL descriptors use only version `3`; descriptors include native-parsed TypeTable, ArgTable, ResourceTable, StructTable, and SpecTable sections. Native validation/lowering and Haxe launch decoding canonicalize parameter/resource/spec lowering from these tables before compiling or launching the KernelIr body; `DescriptorV2` and the old descriptor docs path have been removed. JSON metadata has matching header/type/arg/resource/spec/capability fields, and `Diagnostics.dumpDescriptor(...)` exposes the parsed canonical tables. | No Phase 2 blocker remains; add new golden snapshots only when introducing new resource forms in later phases. | `TestDescriptorSnapshot.hx`, `tests/hashlink/descriptor/DescriptorGoldenSnapshot.hx`, `hashlink_descriptor_golden`; `haxe_descriptor.md`. |
| 3. Typed kernel launch and ArgEncoder | Partial | `Kernel.build` can infer `QKernel0`...`QKernel12`; generated launch closures call specialized `ArgWriter` methods; many compile-fail cases exist; public dynamic launch was removed from `Kernel`; `Spec<T>` values are split from runtime launch args before crossing into native specialization. | Typed wrappers still encode through internal heterogeneous buffers and `KernelRaw` remains the explicit bridge boundary. | `TestTypedKernelRuntime.hx`, compile-fail cases, v3 smoke. |
| 4. QdArgs, Spec, data-oriented | Partial | `@:build(quadrants.macro.QdArgs.build())`, resource flattening, primitive/spec classification metadata, nested QdArgs support, `@:kernel` instance forwarders, descriptor SpecTable entries, and launch-time native specialization/cache keys for `Spec<T>` exist. | Legacy `@:qdFlatten`/`@:qdDataOriented` paths are still accepted; deeper object-specialization cache normalization needs more coverage. | v3 smoke, `QdArgs*`/`Spec*` compile-fail cases, `haxe_kernel_v3.md`. |
| 5. QdStruct and compound storage | Mostly complete | `@:build(quadrants.macro.QdStruct.build())` validates POD fields; `StructTensor<S>` and `StructField<S>` allocate member resources; `StructTensor<S>` kernel parameters support load-copy-store (`var p = particles[i]; ...; particles[i] = p`) and direct scalar/vector/matrix/nested member load/store through descriptor-expanded member resources and StructTable metadata. | Packed workaround APIs remain as shims. | v3 smoke covers scalar, vector-lane, and nested struct kernel load/store; QdStruct/StructTensor compile-fail cases; `dynamic_boundaries.md` lists retained shims. |
| 6. Tensor/Field/SNode/layout/host movement | Partial | Tensor read/write/copy/fill/bytes/DLPack/external-pointer methods exist; direct `Field<T>` kernel params pass SNode ids; dense/pointer/bitmasked/dynamic/quantArray placement paths exist. | Field mirror compatibility code and diagnostics remain; layout/order/offset descriptor validation is incomplete; `dynamic_` and `placeMany` compatibility helpers remain. | v3 smoke; legacy runtime SNode/tensor tests; `kernel_language.md`, `haxe_api_v3.md`. |
| 7. AD/Tape/custom gradient | Partial | `grad()`, `forwardGrad()`, `validationKernel()`, `Tape.withLoss`, typed `launchTape(...)`, and `CustomGradient.register(...)` exist. Public `Tape.launch(...Dynamic)` was removed. | Tape replay still stores heterogeneous internal argument snapshots; edge-case AD validation is incomplete. | Legacy AD/Tape tests; `haxe_kernel_v3.md`. |
| 8. Streams/events/graph | Partial | `Context.createStream`, `StreamEvent`, typed `launchOn`, typed graph control tensors on `QKernelN`, and `Graph.parallel` host composition exist. | Stream-parallel backend capability is false; `StreamParallel.block` is rejected; typed graph do-while uses host-side control in generated wrappers rather than full native graph semantics. | Legacy stream/graph tests; `haxe_kernel_v3.md`. |
| 9. Algorithms/per-thread linalg | Partial | `Algorithms.reduceAdd/reduceMin/exclusiveScanAdd/select/radixSort/radixSortPairs/reduceByKeyAdd`, `Scratch`, and host semantic `Linalg.svd2/svd3/symEig2/symEig3/eig2/polar2/polar3/solve2/solve3/makeSpd` exist. | Device-kernel intrinsic lowering and performance parity are not established. | v3 smoke covers `reduceAdd`, `solve2`, `symEig2`, and `svd2`; legacy algorithms/linalg tests cover current supported paths. |
| 10. Sparse/Mesh/Quant | Mostly complete | Sparse F32/F64 host-reference matrices/solvers, typed host mesh handles, static mesh-for lowering, mesh relation/attribute kernel access through canonical mesh resource descriptors, native SNode-backed mesh topology handles, field-backed mesh attributes, quant descriptors, int/fixed `quantArray(...).placeQuant(...)`, native `bitStruct(...).placeQuant(...)`, quant-float SNode placement, `QuantizedF32Tensor` kernel read/write parameters, sparse `buildFromTensor`, MatrixMarket write, and host matvec helpers exist. | Native sparse backend/performance parity remains capability-gated; mesh index-conversion/reorder optimization coverage should be expanded. | v3 smoke covers mesh relation/attribute native topology, quantized kernel params, and quant-float bitStruct placement; sparse/mesh/quant legacy runtime and compile-fail tests; `haxe_api_v3.md`, `haxe_capabilities.md`. |
| 11. Profiler/diagnostics/release | Partial | Profiler query APIs, scoped trace-event recording, diagnostics dumps, coverage hooks, native/Haxe ABI self-check, version constants, haxelib metadata, and packaging script exist. | Memory profiler is capability-gated; release package layout validation is still limited. | Legacy profiler/diagnostics/release tests; `haxe_release_readiness.md`, `dynamic_boundaries.md`. |

## Current conclusion

The repository now implements the v3 descriptor/resource and mesh-topology blockers that previously prevented the Haxe/HashLink binding from using canonical descriptor tables for native argument/resource semantics. Some broad release-readiness items remain capability-gated or intentionally low-performance (for example native sparse backend parity, stream-parallel backend lowering, and expanded golden snapshot coverage), so this page should still be read as a status ledger rather than a release declaration.

For release gating, treat these as the minimum checks:

1. `ctest --test-dir build/hashlink-cpu-clang --output-on-failure`
2. `tools/check_public_dynamic.sh`
3. `make -C docs xml`

Before marking a phase complete, add or refresh all three coverage classes from the plan where applicable: compile-fail tests, normalized descriptor snapshots, and runtime semantic tests, plus user-guide documentation for the public API or explicit unsupported boundary.
