# Haxe/HashLink release readiness

This page summarizes the stabilized Haxe/HashLink public surface and the checks that should pass before publishing a HashLink package or calling a backend build supported.

## Public API classification

| Class | APIs | Status | Policy |
| --- | --- | --- | --- |
| Final typed APIs | `Context.create`, `Tensor<T>`, `Field<T>`, `StructTensor<S>`, `StructField<S>`, typed `Kernel.build`, `Spec<T>`, `QdArgs`, `QdStruct`, typed `quadrants.algorithms`, `quadrants.linalg`, `quadrants.mesh`, `quadrants.quant`, `Tape`, streams, graph helpers | Recommended for user code | Source compatibility is subordinate to the typed API and safety guarantees. Do not add compatibility shims for removed raw/legacy paths. |
| Capability-gated APIs | stream events, multi-block `Graph.parallel`, DLPack/external pointer import, CUDA/GL interop, native sparse acceleration, backend memory profiler | Public when capability probes report support | User code must branch on `ctx.capabilities()` or extension probes. Unsupported paths should raise explicit errors. |
| Diagnostic / ABI boundaries | internal raw launch arrays, typed-tape replay args, diagnostics snapshots, profiler summaries, CUDA/GL `glBuffer:Dynamic`, helper `Class<Dynamic>` lists | Permanent but narrow | These are documented in [HashLink public Dynamic boundaries](dynamic_boundaries.md) and are not precedents for normal public API typing. |

## Backend support matrix

| Feature family | CPU / LLVM-backed host | CUDA / AMDGPU / Vulkan / Metal |
| --- | --- | --- |
| Primitive tensors/fields, typed kernels, descriptor validation | Default runtime semantic gate | Available when the native backend is compiled in and the driver/runtime is visible to `hl`. |
| Field/SNode placement, layout order, offsets | Runtime-tested | Descriptor/native lowering is shared; backend coverage depends on native SNode support. |
| AD/Tape/custom gradients | Runtime-tested for supported control flow and floating dtypes | Backend-gated through native autodiff/codegen support. Dynamic reverse/validation AD for `while` remains a core limitation and must fail explicitly. |
| Streams/events/graph | CPU covers launch, graph launch, host/native graph loops, and unsupported event paths | CUDA/AMDGPU optional tests cover stream-event ordering and multi-stream `Graph.parallel`; CPU stream events are not a supported native feature. |
| Algorithms/linalg | Runtime-tested reference semantics | Usable where scalar control-flow kernels are supported; performance-tuned device algorithms are backend-specific. |
| Device linalg helpers | Kernel semantic coverage for scalar helpers and `LinalgDevice` aggregate facade | Lower through normal kernel helper inlining. |
| Sparse | F32/F64 COO/CSR native bulk bridge, MatrixMarket roundtrip, matvec, explicit solver fallback, duplicate/invalid-input validation | `caps.sparse.nativeBackend` reports acceleration when a native backend exists; semantic bridge remains separate from acceleration. |
| Mesh | Host save/load/reorder, relation/attribute kernel params, index conversion, `Mesh.for*` loops | Mesh resource descriptors lower through relation-carried metadata; backend support follows native mesh capability. |
| Quant | Quantized tensor kernel parameters, quant-array/bit-struct placement, saturation/rounding tests | Unsupported quant forms fail descriptor/capability validation. |
| Profiler/diagnostics | Kernel profiler, scoped trace events, memory availability, and typed byte counters | Probe through `caps.profiler`; memory counters are backend-defined. |

## Default release gate

A normal CPU/LLVM HashLink release build should run:

```bash
ctest --test-dir build/hashlink-cpu-clang --output-on-failure
```

The expected default CTest entries are:

```text
hashlink_haxe_compile
haxe_v3_smoke
hashlink_v3_runtime_semantic
hashlink_descriptor_golden
hashlink_macro_compile_fail
hashlink_public_dynamic_scan
hashlink_package_validate
```

What they cover:

| Test | Purpose |
| --- | --- |
| `hashlink_haxe_compile` / `haxe_v3_smoke` | Compile and run the package smoke program. |
| `hashlink_v3_runtime_semantic` | Runtime semantic coverage for typed kernels, QdArgs/QdStruct, tensors/fields/SNodes, AD/Tape, streams/graph, algorithms/linalg, sparse/mesh/quant, diagnostics, profiler, and version checks. |
| `hashlink_descriptor_golden` | Descriptor schema snapshots and validation behavior. |
| `hashlink_macro_compile_fail` | User-facing macro diagnostics for unsupported syntax, dtype mismatches, resource misuse, stream misuse in kernel bodies, invalid mesh/quant forms, and removed API surfaces. |
| `hashlink_public_dynamic_scan` | Ensures public `Dynamic` use remains confined to documented boundaries. |
| `hashlink_package_validate` | Builds a haxelib zip and validates metadata, source layout, native symbols, runtime bitcode, and package contents. |

When building CUDA or AMDGPU support, also run the optional backend-depth CTest entries if they are registered:

```text
hashlink_v3_cuda_backend_semantic
hashlink_v3_amdgpu_backend_semantic
```

These tests are allowed to report a structured skip when no device/runtime is available, but they should pass on machines that claim backend support.

## Performance and benchmarks

`benchmarks/hashlink/BenchmarkMain.hx` emits JSON timing data without pass/fail thresholds. Keep performance policy outside the public API so local hardware variance does not create false failures.

For examples or ad-hoc release smoke tests, `quadrants.compat.PerfBaseline.measure(label, iterations, body)` records elapsed seconds and seconds per iteration:

```haxe
var sample = PerfBaseline.measure("small-copy", 10, function() {
  ctx.sync();
});
trace(sample.secondsPerIteration);
```

## Documentation checklist

For every public API or behavior change:

- Update [Haxe/HashLink API](haxe_api.md) for user-facing usage.
- Update [Haxe kernels](haxe_kernel_v3.md) or [Haxe kernel language](kernel_language.md) when the kernel DSL changes.
- Update [Haxe capabilities](haxe_capabilities.md) when a feature becomes capability-gated or changes error behavior.
- Update [HashLink public Dynamic boundaries](dynamic_boundaries.md) whenever a public `Dynamic` is added, removed, or reclassified.
- Rebuild docs with `make -C docs html`.

## Packaging checklist

- Configure with the intended backend flags and `QD_WITH_HASHLINK=ON`.
- Build `quadrants.hdll`.
- Run the default CTest gate.
- Run optional CUDA/AMDGPU backend-depth tests on a matching machine when those backends are enabled.
- Package with `scripts/package_hashlink_haxelib.sh`.
- Verify the package can compile and run the smoke program through `haxe -lib quadrants ...` and `hl ...`.
