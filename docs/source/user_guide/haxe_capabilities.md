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

Nested groups (`streams`, `graph`, `descriptor`, `sparse`, `mesh`, `quant`, `profiler`, `interop`, `version`) remain available for structured diagnostics. Unsupported features should fail with capability/validation errors rather than silently falling back to host or mirror paths.

Diagnostics and profiler helpers are structured:

```haxe
Diagnostics.health(ctx);
Diagnostics.dumpCapabilities(ctx);
Diagnostics.dumpDescriptor(kernel);

Profiler.withScope(ctx, "step", () -> step.launch(...));
final stats = ctx.profiler().kernel("step");
```
