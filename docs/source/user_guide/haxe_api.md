# Haxe/HashLink public API

This page is the v3 public API index. API v3 is intentionally breaking: old raw launch, legacy flatten/template annotations, packed compound workarounds, descriptor V2, and field-mirror fallback are not documented public paths.

Use these v3 guides as the source of truth:

- [Haxe/HashLink API v3](haxe_api_v3.md) for context, tensors/fields, resource types, algorithms, sparse/mesh/quant, profiler, diagnostics, and release behavior.
- [Haxe kernels v3](haxe_kernel_v3.md) for typed `Kernel.build(...)`, `Spec<T>`, `QdArgs`, `QdStruct`, Tape, streams, graph, and kernel language examples.
- [Haxe descriptor metadata](haxe_descriptor.md) for QDHL schema version `3` descriptor inspection.
- [Haxe capabilities](haxe_capabilities.md) for explicit backend capability gates.
- [Haxe v2 to v3 migration](haxe_migration_v2_to_v3.md) for one-way source migrations without runtime shims.

Minimal v3 example:

```haxe
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

var ctx = Context.create({arch: Arch.Cpu});
var x = new Tensor<I32>(ctx, [4]);
var y = new Tensor<I32>(ctx, [4]);

var addOne = Kernel.build(ctx, macro (input:Tensor<I32>, output:Tensor<I32>) -> {
  for (i in 0...4) {
    output[i] = input[i] + 1;
  }
});

addOne.launch(x, y);
ctx.sync();
```

The documented resource families are:

```haxe
Tensor<T>
Field<T>
StructTensor<S>
StructField<S>
```

`Kernel.build(ctx, macro (...)->{...})` returns a typed `QKernelN` wrapper with typed `launch`, `launchOn`, graph helpers, Tape integration, descriptor inspection, and AD wrapper methods. Low-level native bridge internals are intentionally outside the v3 user API.
