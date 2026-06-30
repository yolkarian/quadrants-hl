# Haxe descriptor metadata

> API v3 uses QDHL descriptor schema version `3`. Use `quadrants.descriptor.Descriptor.fromKernel(...)` or `DescriptorV3.fromKernel(...)` to inspect normalized descriptor metadata.

HashLink kernels emit a QDHL binary descriptor with native TypeTable, ArgTable, ResourceTable, StructTable, and SpecTable sections, plus a normalized JSON metadata blob under the `qdhl.meta.json` descriptor attribute. Native validation and lowering canonicalize kernel parameter/resource/spec types from these tables before compiling the KernelIr body. `Diagnostics.dumpDescriptor(...)` parses the same canonical tables (`typeTable`, `argTable`, `resourceTable`, `structTable`, `specTable`) so descriptor snapshots verify the binary schema, not just the JSON attribute.

```haxe
var kernel = Kernel.build(ctx, macro (x:Tensor<I32>, n:I32) -> {
  x[0] = n;
}, {name: "descriptor_plain"});

var meta = quadrants.descriptor.Descriptor.fromKernel(kernel);
trace(meta.version);           // 3
trace(meta.args[0].sourcePath); // "x"
```

The default v3 CTest suite includes descriptor golden snapshots for primitive/spec, direct field-resource, and QdStruct/StructTensor descriptors, plus an invalid schema-version runtime validation check.

The old `DescriptorV2` alias has been removed from the v3 package.
