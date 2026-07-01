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
- `streamParallel` (true only when the backend exposes event-capable native streams)
- `nativeSparse`
- `memoryProfiler`

Nested groups (`streams`, `graph`, `descriptor`, `sparse`, `mesh`, `quant`, `profiler`, `interop`, `version`) remain available for structured diagnostics. Sparse exposes `sparse.hostReference` and `sparse.nativeBackend`; the HashLink v3 CPU path is a validated host-reference sparse bridge unless `sparse.nativeBackend` reports true. Mesh index conversion is exposed as `mesh.indexConversion`; HashLink relations carry local-to-global, local-to-reordered, and global-to-reordered I32 mapping fields into kernel descriptors, with identity behavior when no mapping is installed. `profiler.memory` / `memoryProfiler` is true on LLVM-backed backends where the core Quadrants memory profiler is available. Unsupported features fail with capability/validation errors rather than silently falling back to host or mirror paths.

Diagnostics and profiler helpers are structured:

```haxe
Diagnostics.health(ctx);
Diagnostics.dumpCapabilities(ctx);
Diagnostics.dumpDescriptor(kernel);

Profiler.withScope(ctx, "step", () -> step.launch(...));
final stats = ctx.profiler().kernel("step");
if (ctx.capabilities().memoryProfiler) {
  final memory = ctx.profiler().memoryStats();
  ctx.profiler().printMemory();
}
```
