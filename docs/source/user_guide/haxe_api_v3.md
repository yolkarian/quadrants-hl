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

`Kernel.build(ctx, macro (...)->{...})` is the v3 kernel entrypoint. Give every parameter an explicit type. Raw dynamic launch remains only as a low-level/legacy escape hatch through `KernelRaw` or a value explicitly typed as `Kernel`.
