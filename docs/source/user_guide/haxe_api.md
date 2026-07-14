# Haxe/HashLink API

The Haxe/HashLink binding exposes one typed, descriptor-driven public API. Old raw launch paths, legacy flatten/template annotations, packed compound workarounds, earlier descriptor-schema aliases, and field-mirror fallbacks are not documented or supported public paths.

Most examples use these imports:

```haxe
import quadrants.Algorithms;
import quadrants.Context;
import quadrants.Field;
import quadrants.Diagnostics;
import quadrants.Graph;
import quadrants.Kernel;
import quadrants.LayoutPolicy;
import quadrants.Matrix;
import quadrants.Mesh;
import quadrants.Profiler;
import quadrants.Quant;
import quadrants.Spec;
import quadrants.StructField;
import quadrants.StructTensor;
import quadrants.Tape;
import quadrants.Tensor;
import quadrants.Vec3;
import quadrants.Vector;
import quadrants.ad.CustomGradient;
import quadrants.algorithms.Scratch;
import quadrants.funcs.DeviceLinalg;
import quadrants.funcs.Linalg;
import quadrants.funcs.LinalgDevice;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;
```

## Contexts and lifetime

Create a `Context` for one backend. All tensors, fields, kernels, streams, sparse matrices, and mesh native handles used together must belong to the same context.

```haxe
final ctx = Context.create({
  arch: Arch.Cpu,
  fastMath: true,
  boundsCheck: true,
  offlineCache: {enabled: true, path: ".qd-cache", cleanPolicy: CacheCleanPolicy.Lru, maxSizeBytes: haxe.Int64.ofInt(64 * 1024 * 1024), cleanFactor: 0.25},
  compile: {numThreads: 8, cfgOptimization: true, optLevel: OptLevel.O2, externalOptLevel: OptLevel.O1},
  debug: {printIr: false, launchDebug: false, timeline: false},
  memory: {deviceMemoryFraction: 0.5, cudaStackLimitBytes: 8192}
});
```

Every documented `ContextOptions` field is applied to the native runtime configuration: offline-cache eviction (`cleanPolicy` accepts `Lru`, `Never`, `Version`, `Fifo`, plus `maxSizeBytes` and `cleanFactor`), compile options (`cfgOptimization`, `numThreads`, `optLevel`/`externalOptLevel` as `O0`..`O3`), debug mode and timeline recording, and memory limits (`deviceMemoryFraction`, `cudaStackLimitBytes`). `numThreads`, `cudaStackLimitBytes`, and `deviceMemoryFraction` are consumed while the native runtime is constructed (compile worker pool, CUDA stack limit, device preallocation), so they can only be set through `Context.create` options. The remaining settings also have typed post-creation setters (`ctx.setOptLevel(...)`, `ctx.setTimeline(...)`, `ctx.setOfflineCachePolicy(...)`, ...), and invalid values throw. When `debug.timeline` is enabled, `Context.timelineClear()` and `Context.timelineSave(path)` reset and export the recorded timeline events as JSON; `timelineSave` throws when the output file cannot be written.

Call `ctx.sync()` before reading host results that were produced by launched kernels or backend operations. Close kernels and long-lived resources before closing the context:

```haxe
kernel.close();
tensor.close();
ctx.close();
```

HashLink finalizers are a safety net, not a lifetime policy. Explicit close calls make backend shutdown deterministic and make context-mismatch errors easier to diagnose.

## Tensors and fields

Main public resource families are `Tensor<T>`, `Field<T>`, `StructTensor<S>`, and `StructField<S>`. Rank, layout, and backend capability are validated by descriptors/runtime rather than encoded as extra type parameters.

Primitive tensors are allocated with a context, dtype type parameter, and shape:

```haxe
final x = new Tensor<F32>(ctx, [1024]);
final y = new Tensor<F32>(ctx, [1024]);
x.fill(0.0);
x.write(7, 3.5);
trace(x.read(7));

final image = new Tensor<F32>(ctx, [height, width]);
image.writeAt([row, col], 1.0);
trace(image.readAt([row, col]));
```

Host movement is method-based and typed:

```haxe
y.copyFrom(x);
final values = x.toArray();
x.fromArray(values);
final bytes = x.readBytes();
x.writeBytes(bytes);
x.saveNpy("x.npy");
final loaded = ctx.loadNpy("x.npy"); // TensorRuntime; actual object is dtype-specific
if (loaded.dtype == DType.F32) {
  final loadedF32:Tensor<F32> = cast loaded;
}
```

`.npy` I/O is native and supports primitive tensors in C-order row-major layout. `Context.loadNpy(...)` allocates the tensor once from the file's dtype and shape, then returns it as `TensorRuntime`; the returned object's concrete runtime class is the dtype-specific generated tensor class, so an explicit Haxe `cast` is valid after checking `dtype`.

The cast is a typed view of the same loaded tensor object: it does not copy data and does not allocate another native tensor. Do not use it to convert dtypes; cast only after matching the file dtype, and close the loaded tensor once through either the `TensorRuntime` reference or the typed `Tensor<T>` reference.

```haxe
final loaded = ctx.loadNpy("weights.npy");
switch (loaded.dtype) {
  case DType.F32:
    final weights:Tensor<F32> = cast loaded;
    useF32(weights);
  case other:
    loaded.close();
    throw 'weights.npy has unsupported dtype ${other}';
}
```

Interop is explicit:

```haxe
final capsule = x.toDLPack();
y.importDLPack(capsule);
final ptr = x.devicePointer();
y.importExternalPointer(ptr);
```

`shape` and `dtype` are typed properties; `rank()`, `numel()`, and `shapeCopy()` provide stable method-style queries.

Fields are placed through `ctx.root` and passed to kernels as direct SNode resources. Fields are not mirrored through tensors on launch.

```haxe
final f = new Field<I32>(ctx, [4]);
ctx.root.dense([4], {offset: [10]}).place(f);
ctx.root.dense([rows, cols], {order: [1, 0]}).place(g);
```

Host `Field.read/write(flatIndex, ...)` remains zero-based over the declared shape. Kernel indexing uses Quadrants logical indices, so an offset field placed at `[10]` is accessed as `f[10] ... f[13]` inside kernels.

Autodiff `grad`/`dual` storage is available only for real floating dtypes (`F16`/`F32`/`F64`). Integer and boolean tensors/fields raise explicit no-grad errors.

## Kernels and specialization

`Kernel.build(ctx, macro (...)->{...})` is the kernel entrypoint. Give every parameter an explicit type. The generated wrapper has typed `launch`, `launchOn`, graph, Tape, and descriptor methods.

```haxe
final add = Kernel.build(ctx, macro (a:Tensor<F32>, b:Tensor<F32>, out:Tensor<F32>, n:Int) -> {
  for (i in 0...n) {
    out[i] = a[i] + b[i];
  }
});

add.launch(x, y, y, x.numel());
ctx.sync();
```

Use `Spec<T>` for specialization-only constants. Spec values are part of the descriptor specialization/cache key and are not runtime kernel arguments.

```haxe
final scaleFixedN = Kernel.build(ctx, macro (x:Tensor<F32>, n:Spec<Int>, scale:F32) -> {
  for (i in 0...n) {
    x[i] = x[i] * scale;
  }
});
scaleFixedN.launch(x, Spec.of(1024), 2.0);
```

Low-level raw handles and native argument arrays are bridge internals. User code should launch through the typed wrapper returned by `Kernel.build`.

## QdArgs containers

Host containers use `@:build(quadrants.macro.QdArgs.build())`. Resource members flatten to runtime resource arguments; primitive/enum members, including nested QdArgs primitive members, lower to `Spec<T>` specialization parameters.

```haxe
@:build(quadrants.macro.QdArgs.build())
class SimState {
  public var x:Tensor<F32>;
  public var n:Int;

  public function new(ctx:Context, n:Int) {
    this.x = new Tensor<F32>(ctx, [n]);
    this.n = n;
  }

  @:kernel public function clear():Void {
    for (i in 0...n) {
      x[i] = 0.0;
    }
  }
}

final state = new SimState(ctx, 1024);
state.clear();
ctx.sync();
```

Use explicit kernel parameters for runtime scalar values that should not specialize the compiled kernel.

## QdStruct, StructTensor, and StructField

Device POD structs use one build macro:

```haxe
@:build(quadrants.macro.QdStruct.build())
class Particle {
  public var id:I32;
  public var mass:F32;
  public var pos:Vec3;
}

final particles:StructTensor<Particle> = StructTensor.alloc(ctx, [n], LayoutPolicy.AOS);
particles.writeMember("id", 0, 7);
```

`QdStruct` rejects resources, `Array`, `String`, `Dynamic`, function fields, and arbitrary classes. `StructTensor` defaults to AOS; `StructField` defaults to SOA. Kernels can load-copy-store structs (`var p = particles[i]; ...; particles[i] = p`) and can directly read/write scalar, vector/matrix lane, and nested members (`particles[i].id = ...`, `particles[i].pos.x = ...`, `wrappers[i].particle.id = ...`).

## Autodiff and Tape

Generated typed kernels expose `launchTape(tape, ...)`, `grad()`, `forwardGrad()`, and `validationKernel()` when the descriptor supports the requested autodiff transform.

```haxe
Tape.withLoss(ctx, loss, tape -> {
  forward.launchTape(tape, x, y, n);
  reduce.launchTape(tape, y, loss, n);
});
```

Custom gradients are explicit registrations:

```haxe
final custom = CustomGradient.register(forward, {
  backward: backward,
  forwardGrad: forwardGrad,
  validation: validation
});
```

`launchTapeOn(stream, tape, ...)` is intentionally unsupported. Record Tape launches on the default stream and use explicit streams outside Tape scopes.

## Streams and graph helpers

Streams are explicit host objects:

```haxe
final stream = ctx.createStream();
k.launchOn(stream, x, y, n);
stream.sync();
```

Events are available only when the backend exposes native stream events. Probe `ctx.capabilities().streams.events` before using them:

```haxe
if (ctx.capabilities().streams.events) {
  final event = ctx.createEvent();
  event.record(stream);
  otherStream.wait(event);
}
```

Graph helpers are typed:

```haxe
k.launchGraph(args...);
k.launchGraphWhile(controlI32Tensor, args...);
k.launchGraphDoWhile(controlI32Tensor, args...); // control tensor must also be one of args
```

`Graph.parallel(ctx, blocks)` accepts a single block everywhere. Multiple blocks require `ctx.capabilities().streamParallel`; unsupported backends throw instead of pretending to run in parallel. Use `Graph.sequence(ctx, blocks)` when sequential composition is intended.

## Algorithms and linalg

Device-wide algorithms are available through one facade and use typed tensors plus a reusable scratch manager:

```haxe
final scratch = Scratch.create(ctx);
scratch.reserve(4096);
Algorithms.reduceAdd(ctx, input, output, scratch);
Algorithms.exclusiveScanAdd(ctx, input, output, scratch);
Algorithms.radixSort(ctx, keys, tmpKeys, scratch, {beginBit: 0, endBit: 32});
scratch.clear();
```

Host per-thread linalg entrypoints live under `quadrants.funcs.Linalg` with explicit sizes (`svd2`, `svd3`, `solve2`, `solve3`, ...). Kernel-side helper coverage lives in `quadrants.funcs.DeviceLinalg` `@:qdFunc` scalar helpers: solve2/solve3, 2D eig/symEig/svd/polar components, and 3D selector helpers (`symEig3Value(..., which)`, `svd3Sigma(..., which)`, `polar3R(..., component)`, `makeSpd3(..., component)`).

For kernel-local aggregate values, include both `DeviceLinalg` and `LinalgDevice` in the helper list. `LinalgDevice` assembles scalar helpers into `Vector<Float>`/`Matrix<Float>` returns:

```haxe
final deviceLinalg = Kernel.build(ctx, macro (out:Tensor<F32>) -> {
  var A = Matrix.ofArray(2, 2, [2.0, 0.0, 0.0, 4.0]);
  var b = Vector.ofArray([6.0, 8.0]);
  var x = LinalgDevice.solve2(A, b);
  out[0] = x[0];
  out[1] = x[1];
}, {helpers: [DeviceLinalg, LinalgDevice]});
```

Pass scalar lanes directly or via `matrix.kernelGet(row, col)` inside kernels.

## Sparse matrices

Sparse resources use typed constructors plus descriptor/capability validation:

```haxe
final A = quadrants.linalg.SparseMatrix.fromCOO(ctx, rowInd, colInd, values, nRows, nCols);
final nnz = A.toCSR(rowPtrOut, colIndOut, valuesOut);
A.buildFromTensor(dense, {eps: 1e-6});
A.mmwrite("A.mtx");
final B = quadrants.linalg.SparseMatrix.mmread(ctx, "A.mtx", DType.F32);
```

`SparseMatrix.fromCOO`, `fromCSR`, `toCOO`, and `toCSR` use native bulk bridge paths for F32/F64 tensors. COO/CSR exports are row-major sorted. Duplicate COO/CSR entries use last-writer-wins semantics, matching repeated `set(row, col, value)` calls; a later zero value removes that entry. Invalid CSR row pointers and out-of-bounds coordinates raise validation errors.

`SparseSolver` exposes explicit host-dense fallback policy. Do not rely on silent fallback when native sparse acceleration is unavailable; check `ctx.capabilities().sparse` when backend selection matters.

## Mesh resources

Host mesh containers expose counts, relations, attributes, JSON save/load, reorder, and index mappings:

```haxe
final mesh = new Mesh(vertexCount, edgeCount);
mesh.save("mesh.qdmesh.json");
final loaded = Mesh.load(ctx, "mesh.qdmesh.json");
mesh.setIndexMapping(quadrants.Mesh.MeshElementType.Vertex, quadrants.Mesh.MeshIndexConversion.LocalToGlobal, localToGlobalVertex);
final reordered = mesh.reorder(quadrants.Mesh.MeshElementType.Vertex, newToOldVertexOrder);
```

Mesh relation/attribute kernel parameters use canonical mesh resource descriptors. Relations lower through native topology handles backed by SNode relation resources, and attributes lower to field-backed mesh resources. Kernels can call `relation.size(i)`, `relation.get(i, j)`, `attribute.read(i)`, and `attribute.write(i, value)`.

Kernel mesh-for loops use static domain counts:

```haxe
for (e in Mesh.forEdges(2)) {
  var sum = 0;
  for (j in 0...relation.size(e)) {
    sum += mass.read(relation.get(e, j));
  }
  edgeSum[e] = sum;
}
```

Mesh index mappings are host-managed with `mesh.setIndexMapping(...)` and saved/loaded in the HashLink JSON mesh schema. Kernels can call `relation.sourceLocalToGlobal(e)`, `relation.targetLocalToGlobal(v)`, `sourceIndexLocalToGlobal(i)`, `targetIndexLocalToGlobal(i)`, and the corresponding `LocalToReordered`/`GlobalToReordered` helpers. Missing mappings lower to identity.

## Quantization

Quant descriptors are explicit values:

```haxe
final qi8 = Quant.intI32({bits: 8, signed: true});
```

`QuantizedF32Tensor` kernel parameters support `read(i)` dequantization and `write(i, value)` quantization through descriptor-expanded raw storage and quantization constants. `bitStruct(...).placeQuant(...)` supports quant-float placement. Unsupported native sparse/mesh/quant paths throw capability or validation errors instead of silently falling back.

## Sparse grids, index rescaling, and host linalg

`quadrants.sparse.SparseGrid` builds a 2D/3D bitmasked grid of named member fields under one shared bitmasked parent, mirroring the Python binding's `qd.sparse.grid(...)`:

```haxe
final grid = quadrants.sparse.SparseGrid.create2(ctx, 64, 64);
final mass = grid.addF32("mass");
final id = grid.addI32("id");
grid.commit();
// kernel writes activate cells; struct-for over a member visits active cells only
trace(grid.activeCount());
trace(grid.usage()); // active fraction in [0, 1]
```

Field placement offsets may be negative (`ctx.root.dense([8], {offset: [-4]})`); host accessors keep zero-based flat indices over the declared shape while kernels see logical offset-based indices. `quadrants.snode.RescaleIndex.map(fromShape, toShape, index)` rescales grouped loop indices between fields whose shapes are related by integer factors, matching the Python `rescale_index` semantics.

`quadrants.funcs.Linalg.symEigGeneral(m)` computes the symmetric eigendecomposition of any square host `Matrix<T>` via cyclic Jacobi (ascending eigenvalues, eigenvector columns), and `Linalg.makeSpd(m)` now accepts any square size. `quadrants.simt.SubgroupSegmented` provides kernel-side segmented subgroup reductions (`segmentedReduceAdd/Min/MaxI32`, `...F32`) that reset at non-zero head flags.

## Capabilities, diagnostics, and profiler

Use capabilities instead of backend-name checks when feature availability matters:

```haxe
final caps = ctx.capabilities();
if (caps.streamParallel) {
  Graph.parallel(ctx, blocks);
}
```

Diagnostics and profiler helpers are structured:

```haxe
Diagnostics.health(ctx);
Diagnostics.dumpCapabilities(ctx);
Diagnostics.dumpDescriptor(kernel);

Profiler.withScope(ctx, "step", () -> step.launch(...));
final stats = ctx.profiler().kernel("step");
if (ctx.capabilities().memoryProfiler) {
  final memory = ctx.profiler().memoryStats();
  trace(memory.allocatedBytes);
  trace(memory.snodeBytes);
  trace(memory.ndarrayBytes);
}
```

Memory profiler counters are typed `haxe.Int64` values. `allocatedBytes` is the total tracked allocation count currently exposed by the HashLink bridge; `snodeBytes` and `ndarrayBytes` split SNode-backed and ndarray-backed storage where the backend reports those values.

`ctx.profiler().traceRecords()` returns the backend kernel profiler's per-launch trace records as `{name, durationMs}` entries, and `printInfo(Trace)` prints the same listing followed by the total time, matching the Python binding's `print_kernel_profiler_info("trace")`.
