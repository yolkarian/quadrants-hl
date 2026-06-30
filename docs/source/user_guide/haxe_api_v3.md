# Haxe/HashLink API v3

API v3 is a breaking reset for the Haxe/HashLink binding. The documented path is typed and descriptor driven.

```haxe
final ctx = Context.create({
  arch: Arch.Cpu,
  fastMath: true,
  boundsCheck: true,
  offlineCache: {enabled: true, path: ".qd-cache"},
  compile: {numThreads: 8, cfgOptimization: true},
  debug: {printIr: false, timeline: false}
});

final x = new Tensor<F32>(ctx, [n]);
final f = new Field<I32>(ctx, [n]);
```

Main public resource families are `Tensor<T>`, `Field<T>`, `StructTensor<S>`, and `StructField<S>`. Rank, layout, and backend capability are validated by descriptors/runtime rather than encoded as extra type parameters.

Device POD structs use one build macro:

```haxe
@:build(quadrants.macro.QdStruct.build())
class Particle {
  public var id:I32;
  public var mass:F32;
}

final particles:StructTensor<Particle> = StructTensor.alloc(ctx, [n], LayoutPolicy.AOS);
particles.writeMember("id", 0, 7);
```

`QdStruct` rejects resources, `Array`, `String`, `Dynamic`, function fields, and arbitrary classes. `StructTensor` defaults to AOS; `StructField` defaults to SOA. Kernels can load-copy-store structs (`var p = particles[i]; ...; particles[i] = p`) and can directly read/write scalar, vector/matrix lane, and nested members (`particles[i].id = ...`, `particles[i].pos.x = ...`, `wrappers[i].particle.id = ...`).

Tensor/field host movement is method-based and typed:

```haxe
x.writeAt([i, j], value);
final v = x.readAt([i, j]);
x.fill(0);
y.copyFrom(x);
final bytes = x.readBytes();
x.writeBytes(bytes);
final capsule = x.toDLPack();
final ptr = x.devicePointer();
```

`shape` and `dtype` are typed properties; `rank()`, `numel()`, and `shapeCopy()` provide stable method-style queries. Field parameters are direct SNode resources; v3 does not mirror fields through tensors on launch.

Device-wide algorithms are available through one flat facade:

```haxe
Algorithms.reduceAdd(ctx, input, output, scratch);
Algorithms.exclusiveScanAdd(ctx, input, output, scratch);
Algorithms.radixSort(ctx, keys, tmpKeys, scratch, {beginBit: 0, endBit: 32});
```

Per-thread linalg entrypoints live under `quadrants.funcs.Linalg` with explicit sizes (`svd2`, `svd3`, `solve2`, `solve3`, ...).

Sparse, mesh, and quant resources use typed constructors plus descriptor/capability validation:

```haxe
final A = SparseMatrix.fromCOO(ctx, rows, cols, values, nRows, nCols);
A.buildFromTensor(dense, {eps: 1e-6});
A.mmwrite("A.mtx");
final mesh = new Mesh(vertexCount, edgeCount);
final qi8 = Quant.intI32({bits: 8, signed: true});
```

Mesh relation/attribute kernel parameters use canonical mesh resource descriptors: relations lower through native topology handles backed by SNode relation resources, and attributes lower to field-backed mesh resources. Kernels can call `relation.size(i)`, `relation.get(i, j)`, `attribute.read(i)`, and `attribute.write(i, value)`. `QuantizedF32Tensor` kernel parameters support `read(i)` dequantization and `write(i, value)` quantization through descriptor-expanded raw storage and quantization constants. `bitStruct(...).placeQuant(...)` supports quant-float placement. Unsupported native sparse/mesh/quant paths throw capability or validation errors instead of silently falling back.

`Kernel.build(ctx, macro (...)->{...})` is the v3 kernel entrypoint. Give every parameter an explicit type. Use `Spec<T>` for specialization-only constants; generated typed launchers separate those values from runtime kernel arguments and native caches specialized kernels by the SpecTable values. `Kernel` is now a macro facade; low-level raw handles are internal bridge implementation details rather than a documented user API.
