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

`QdStruct` rejects resources, `Array`, `String`, `Dynamic`, function fields, and arbitrary classes. `StructTensor` defaults to AOS; `StructField` defaults to SOA.

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

`Kernel.build(ctx, macro (...)->{...})` is the v3 kernel entrypoint. Give every parameter an explicit type. Raw dynamic launch remains only as a low-level/legacy escape hatch through `KernelRaw` or a value explicitly typed as `Kernel`.
