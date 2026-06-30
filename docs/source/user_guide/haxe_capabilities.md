# Haxe/HashLink capabilities

Query backend capabilities from the context:

```haxe
final caps = ctx.capabilities();
if (!caps.fieldResourceParam) throw "Field parameters are not supported";
```

Top-level v3 probes:

- `fieldResourceParam`
- `structTensor`
- `meshKernelAccess`
- `quantKernelParam`
- `streamParallel`
- `nativeSparse`
- `memoryProfiler`

Nested groups (`streams`, `graph`, `descriptor`, `sparse`, `mesh`, `quant`, `profiler`, `interop`, `version`) remain available for structured diagnostics. Sparse exposes `sparse.hostReference` and `sparse.nativeBackend`; the HashLink v3 CPU path is a validated host-reference sparse bridge unless `sparse.nativeBackend` reports true. Mesh index conversion optimization is exposed as `mesh.indexConversion` and remains false on backends that do not provide it. Unsupported features fail with capability/validation errors rather than silently falling back to host or mirror paths.

Diagnostics and profiler helpers are structured:

```haxe
Diagnostics.health(ctx);
Diagnostics.dumpCapabilities(ctx);
Diagnostics.dumpDescriptor(kernel);

Profiler.withScope(ctx, "step", () -> step.launch(...));
final stats = ctx.profiler().kernel("step");
```
