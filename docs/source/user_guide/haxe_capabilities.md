# Haxe/HashLink capabilities

Backends do not expose identical runtime features. Query `ctx.capabilities()` and branch on explicit feature flags instead of inferring support from an architecture name.

```haxe
final caps = ctx.capabilities();
if (!caps.fieldResourceParam) {
  throw "Field parameters are not supported";
}
```

## Top-level probes

| Probe | Meaning |
| --- | --- |
| `fieldResourceParam` | Kernels can receive `Field<T>` as direct SNode resources. |
| `structTensor` | `StructTensor<S>` / `StructField<S>` descriptor metadata and lane access are available. |
| `meshKernelAccess` | Mesh relations/attributes can be passed to kernels. |
| `quantKernelParam` | Quantized tensor kernel parameters can lower quant metadata. |
| `streamParallel` | Multiple `Graph.parallel` blocks can run on event-capable native streams. |
| `nativeSparse` | A native sparse backend is reported by the bridge. CPU HashLink currently exposes a validated host-reference sparse bridge unless this is true. |
| `memoryProfiler` | `ctx.profiler().memoryStats()` and `printMemory()` are available on this backend. |

## Nested groups

`ctx.capabilities()` also exposes structured groups:

```haxe
final caps = ctx.capabilities();
trace(caps.streams.events);
trace(caps.graph.nativeDoWhile);
trace(caps.sparse.hostReference);
trace(caps.mesh.indexConversion);
trace(caps.profiler.memory);
trace(caps.interop.dlpack);
trace(caps.version.descriptorVersion);
```

| Group | Important fields |
| --- | --- |
| `streams` | `available`, `events`, `parallelBlocks`. CPU has streams but not native stream events; CUDA/AMDGPU report events when the native build/backend supports them. |
| `graph` | `launch`, `hostWhile`, `nativeDoWhile`. `launchGraphDoWhile` requires the I32 control tensor to also be one of the kernel runtime arguments. |
| `descriptor` | `version`, `maxVersion`, `typedKernelLaunch`, `typedMetadata`. These describe the QDHL descriptor schema accepted by the native bridge. |
| `sparse` | `hostReference`, `nativeBackend`. F32/F64 COO/CSR bulk conversion works on the HashLink sparse bridge; acceleration is backend-specific. |
| `mesh` | `hostHandles`, `kernelRelations`, `kernelAttributes`, `indexConversion`. Missing index mappings lower to identity conversions. |
| `quant` | `quantArrayPlacement`, `bitStructPlacement`, `floatPlacement`, `kernelParameters`. Unsupported quant forms fail validation. |
| `profiler` | `kernel`, `scoped`, `memory`. Kernel timing and memory summaries are queried separately. |
| `interop` | `zeroCopy`, `dlpack`, `externalPointerImport`, `cudaGlInterop`. Pointer-style interop requires backend support and matching lifetimes. |
| `version` | Package/native ABI and descriptor version values useful for diagnostics. |

Unsupported features fail with capability or validation errors rather than silently falling back to host mirrors or fake parallel execution.

## Streams and graph examples

```haxe
if (ctx.capabilities().streams.events) {
  final a = ctx.createStream();
  final b = ctx.createStream();
  kernel.launchOn(a, args...);
  final event = ctx.createEvent();
  event.record(a);
  b.wait(event);
  dependent.launchOn(b, args...);
}

if (ctx.capabilities().streamParallel) {
  Graph.parallel(ctx, [
    () -> first.launchOn(Graph.autoStream(), args...),
    () -> second.launchOn(Graph.autoStream(), args...),
  ]);
} else {
  Graph.sequence(ctx, [
    () -> first.launch(args...),
    () -> second.launch(args...),
  ]);
}
```

`Graph.autoStream()` is valid only inside a host `Graph.parallel` block. It is not a kernel-body API.

## Sparse, mesh, and quant examples

```haxe
final caps = ctx.capabilities();
if (caps.sparse.hostReference || caps.sparse.nativeBackend) {
  final A = quadrants.linalg.SparseMatrix.fromCSR(ctx, rowPtr, colInd, values, rows, cols);
}

if (caps.mesh.indexConversion) {
  mesh.setIndexMapping(MeshElementType.Vertex, MeshIndexConversion.LocalToGlobal, localToGlobal);
}

if (caps.quant.kernelParameters) {
  quantized.write(0, 1.25);
}
```

These probes report API availability, not performance promises. For example, sparse COO/CSR import/export is semantically validated through the HashLink bridge even when `nativeSparse` is false.

## Diagnostics and profiler helpers

Diagnostics are intentionally structured and centralized:

```haxe
Diagnostics.health(ctx);
Diagnostics.dumpCapabilities(ctx);
Diagnostics.dumpDescriptor(kernel);
```

Kernel profiler summaries are keyed by kernel name:

```haxe
Profiler.withScope(ctx, "step", () -> step.launch(...));
final kernelStats = ctx.profiler().kernel("step");
trace(kernelStats.count);
trace(kernelStats.avgMs);
```

Memory profiler summaries are available when `caps.memoryProfiler` is true:

```haxe
if (ctx.capabilities().memoryProfiler) {
  final memory = ctx.profiler().memoryStats();
  trace(memory.available);
  trace(memory.allocatedBytes);
  trace(memory.snodeBytes);
  trace(memory.ndarrayBytes);
  ctx.profiler().printMemory();
}
```

`allocatedBytes`, `snodeBytes`, and `ndarrayBytes` are typed `haxe.Int64` values. `printMemory()` delegates to the backend's native memory-profiler text output, so treat it as a diagnostic side effect rather than a stable parseable format.
