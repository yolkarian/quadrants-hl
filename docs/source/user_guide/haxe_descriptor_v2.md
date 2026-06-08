# Haxe descriptor V2 metadata

HashLink kernels already emit QDHL descriptor version `2`. The Haxe binding now also fills the descriptor attribute section with a canonical JSON metadata blob under `qdhl.meta.json`.

Use `quadrants.descriptor.DescriptorV2.fromKernel(...)` or `Diagnostics.descriptorDump(...)` to inspect it.

```haxe
var kernel = Kernel.build(ctx, macro (x:Tensor<I32>, n:I32) -> {
  x[0] = n;
}, {name: "descriptor_plain"});

var meta = quadrants.descriptor.DescriptorV2.fromKernel(kernel);
trace(meta.args[0].path);      // "x"
trace(meta.args[1].kind);      // "scalar"
trace(meta.capabilities);      // e.g. ["field_direct_param"]
```

For flatten/data-oriented kernels, the metadata preserves the kernel's requested name, keeps source paths such as `state.x`, and records `@:template` members in the `templates` array.
