# Haxe/HashLink release readiness

This page summarizes the stabilized Haxe/HashLink public surface after the typed migration and selected deep-parity tranche.

## Public API classification

| Class | APIs | Status | Migration policy |
| --- | --- | --- | --- |
| Final typed APIs | `Tensor<T>`, `Field<T>`, `VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, `MatrixField<T>`, typed `quadrants.algorithms`, `StructMember<T>` member handles, `quadrants.mesh` typed host handles, `quadrants.quant` descriptors | Recommended for new code | Source compatibility should be preserved unless a safety issue requires a compile-time break. |
| Workaround APIs | `quadrants.packed.Packed*`, `StructOfArraysField`, Haxe-only `QuantizedF32Tensor` | Supported when the layout is useful or native parity is intentionally unavailable | Prefer final typed APIs where they cover the same use case; adapters such as `fromPacked(...)` / `toPacked()` are the migration path. |
| Compatibility shims | String-keyed struct `add/member/read/write`, heterogeneous `Grad.zeroGrad` / `clearAllGradients`, heterogeneous `FieldTree.lazyGrad` helpers | Retained but not recommended | Do not add new examples using these when a typed alternative exists. Deprecation requires replacement examples and compile-fail coverage. |
| Interop boundaries | `Kernel.launch(...values:Dynamic)`, native launch arrays, diagnostics/coverage JSON-like snapshots, CUDA/GL `glBuffer:Dynamic`, helper `Class<Dynamic>` lists | Permanent | These are documented in `bindings/hashlink/haxe/quadrants/DYNAMIC_BOUNDARIES.md` and are not considered normal API typing precedents. |

## Backend support matrix

| Feature family | CPU | CUDA / AMDGPU / Vulkan / Metal |
| --- | --- | --- |
| Primitive tensors/fields, streams/events, graph launch, autodiff basics | Runtime-tested on CPU suites | Available when the built native backend supports the underlying primitive operation; tests are backend-gated. |
| SIMT helpers and packed/compound kernel lowering | Descriptor-tested; selected CPU runtime tests | Lower through the same descriptor ABI; backend support depends on native SIMT/shared-memory support. |
| Algorithms (`Reduce`, `Scan`, `Select`, `Sort`, `ReduceByKey`) | Runtime-tested reference implementations | Usable where scalar control-flow kernels are supported; not performance-tuned device algorithms. |
| Sparse/linalg and profiler bridge | Runtime-tested F32 smoke path | Feature probes report support; acceleration is backend-specific and not promised by the Haxe API. |
| Typed mesh relations/attributes | Host-side runtime-tested | Kernel relation/attribute access is intentionally not public yet. |
| Quant descriptors and `QuantizedF32Tensor` | Haxe-only runtime-tested reference storage | Native quant placement and quantized kernel parameters are intentionally not public yet. |

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
- Run the compile-fail suite; it covers typed algorithm mismatches, storage-kind mismatches, kernel dtype annotation errors, typed struct member mistakes, invalid mesh relation access, invalid quant parameters, and unsupported native quant/SNode operations.
- Run runtime gamma for algorithms, autodiff diagnostics, packed/compound storage, typed mesh/quant/SNode contracts, sparse/profiler, release migration examples, and the performance-baseline harness.
- Update `DYNAMIC_BOUNDARIES.md` whenever a public `Dynamic` is added, removed, or reclassified.
