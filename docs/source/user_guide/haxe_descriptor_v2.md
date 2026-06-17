# Haxe descriptor metadata

> API v3 uses QDHL descriptor schema version `3`. This page is retained at its old path for links; prefer `quadrants.descriptor.Descriptor.fromKernel(...)` or `DescriptorV3.fromKernel(...)` for new code.

HashLink kernels emit a QDHL binary descriptor and a normalized JSON metadata blob under the `qdhl.meta.json` descriptor attribute. The JSON contains header, type table, arg table, resource table, struct/spec tables, capability requirements, and debug info.

```haxe
var kernel = Kernel.build(ctx, macro (x:Tensor<I32>, n:I32) -> {
  x[0] = n;
}, {name: "descriptor_plain"});

var meta = quadrants.descriptor.Descriptor.fromKernel(kernel.descriptor());
trace(meta.version);           // 3
trace(meta.args[0].sourcePath); // "x"
```

`DescriptorV2.fromKernel(...)` remains only as a legacy alias over the same attribute payload.
