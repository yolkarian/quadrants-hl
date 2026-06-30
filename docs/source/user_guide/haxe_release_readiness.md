# Haxe/HashLink release readiness

This page summarizes the stabilized Haxe/HashLink public surface after the typed migration and selected deep-parity tranche.

## Public API classification

| Class | APIs | Status | Migration policy |
| --- | --- | --- | --- |
| Final typed APIs | `Tensor<T>`, `Field<T>`, `StructTensor<S>`, `StructField<S>`, typed `quadrants.algorithms`, `quadrants.mesh` typed host handles, `quadrants.quant` descriptors | Recommended for new code | Source compatibility is subordinate to the v3 typed API and safety guarantees. |
| Interop boundaries | internal raw launch arrays, typed-tape replay args, diagnostics/coverage/profiler JSON-like snapshots, CUDA/GL `glBuffer:Dynamic`, helper `Class<Dynamic>` lists | Permanent | These are documented in [HashLink public Dynamic boundaries](dynamic_boundaries.md) and are not considered normal API typing precedents. |

## Backend support matrix

| Feature family | CPU | CUDA / AMDGPU / Vulkan / Metal |
| --- | --- | --- |
| Primitive tensors/fields, streams/events, graph launch, autodiff basics | Runtime-tested on CPU suites | Available when the built native backend supports the underlying primitive operation; tests are backend-gated. |
| SIMT helpers and packed/compound kernel lowering | Descriptor-tested; selected CPU runtime tests | Lower through the same descriptor ABI; backend support depends on native SIMT/shared-memory support. |
| Algorithms (`Reduce`, `Scan`, `Select`, `Sort`, `ReduceByKey`) | Runtime-tested reference implementations | Usable where scalar control-flow kernels are supported; not performance-tuned device algorithms. |
| Sparse/linalg and profiler bridge | Runtime-tested F32/F64 sparse paths plus typed profiler probes | Feature probes report support; profiler clear/record, typed context options, CUPTI metric presets, and explicit unavailable memory-profiler status are covered. Acceleration is backend-specific and not promised by the Haxe API. |
| Typed mesh relations/attributes | Host-side and kernel runtime-tested | Kernel relation/attribute access uses typed mesh resource metadata, native topology handles, and field-backed attributes. |
| Quant descriptors and `QuantizedF32Tensor` | Haxe reference storage plus native int/fixed `quantArray(...).placeQuant(...)`, `bitStruct`, quant-float placement, and quantized-kernel-parameter smoke coverage | Unsupported quant forms fail through descriptor or capability validation. |

## Performance baselines

`quadrants.compat.PerfBaseline.measure(label, iterations, body)` is a small harness for examples and release smoke tests. It records elapsed seconds and seconds per iteration without imposing thresholds. Store threshold policy outside the API so local hardware variance does not create false failures.

```haxe
var sample = PerfBaseline.measure("small-copy", 10, function() {
  ctx.sync();
});
trace(sample.secondsPerIteration);
```

## Release validation checklist

- Run the HashLink Haxe compile suite.
- Run the compile-fail suite; it covers typed algorithm mismatches, storage-kind mismatches, kernel dtype annotation errors, typed struct member mistakes, invalid mesh relation access, invalid quant parameters, unsupported native quant/SNode operations, unsupported quant kernel parameters, and removed stream-parallel marker APIs.
- Run runtime gamma for algorithms, autodiff diagnostics, packed/compound storage, typed mesh/quant/SNode contracts, sparse/profiler, release migration examples, and the performance-baseline harness.
- Inspect `Context.capabilities()` and `Context.optionWarnings()` on each supported backend so parsed-but-not-yet-wired config surfaces remain explicit; memory profiler availability must be consumed through `caps.profiler.memory` / `caps.memoryProfiler`, not inferred.
- Build a haxelib package with `scripts/package_hashlink_haxelib.sh`; it validates haxelib metadata, source layout, native symbols, runtime bitcode, ROCm/CUDA sidecars, and final zip contents.
- Update [HashLink public Dynamic boundaries](dynamic_boundaries.md) whenever a public `Dynamic` is added, removed, or reclassified.
