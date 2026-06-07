# Haxe/HashLink public API

This page is the Haxe/HL replacement for the former Python binding entry points. New user code should import the `quadrants` Haxe package and run through HashLink JIT bytecode (`haxe -hl ...`, then `hl ...`).

## Execution model

1. Haxe compiles host code to a `.hl` bytecode file.
2. `Kernel.build(ctx, macro (...) -> { ... })` runs at Haxe compile time and serializes the kernel body into a descriptor.
3. At run time, HashLink loads `quadrants.hdll` and calls the native Quadrants bridge.
4. The native bridge JIT-compiles kernels for the selected `Arch`, launches them, and synchronizes through `Context.sync()`.

## Breaking changes: typed Tensor construction

Tensor allocation is now constructor-based and dtype-safe.

Old:

```haxe
var a = ctx.ndarrayI32([n]);
a.writeI32(0, 1);
var x = a.readI32(0);
```

New:

```haxe
var a = new Tensor<I32>(ctx, [n]);
a.write(0, 1);
var x:I32 = a.read(0);
```

Removed APIs:

- `Context.ndarray(dtype, shape)`
- `Context.ndarrayI8/I16/I32/I64`
- `Context.ndarrayU8/U16/U32/U64/U1`
- `Context.ndarrayF16/F32/F64`
- dtype-specific tensor host helpers such as `readI32`, `writeF32`, `fillU1`, `readF64At`, `toArrayI16`, and `fromArrayF32`
- `Context.fieldI32()` and other dtype-specific field helpers

Use `new Field<I32>(ctx, shape)` or `new Field<I32>(ctx)` plus `ctx.root.place(field)` for fields.

## Runtime facade and explicit contexts

Explicit `Context` objects remain the ownership ground truth and are the right choice for libraries or multi-backend programs:

```haxe
var ctx = new Context(Arch.Cpu);
```

Use `ContextOptions` when a context should apply native-backed settings before user code starts building kernels:

```haxe
var opts = ContextOptions.create()
  .withProfiler(true)
  .withOfflineCache(true, "build/qdcache")
  .withCpuMaxNumThreads(4)
  .withBoundsCheck(true);
var configured = Context.fromOptions(opts, Arch.Cpu);
```

For grouped configuration, use the builder API:

```haxe
var opts = ContextOptions.builder()
  .arch(Arch.Cpu)
  .offlineCache({enabled: true, path: "build/qdcache", cleanPolicy: CacheCleanPolicy.Lru})
  .compile({cfgOptimization: true, numCompileThreads: 4, optLevel: OptLevel.O2})
  .defaults({fp: DType.F32, ip: DType.I32, up: DType.U32})
  .memory({deviceMemoryFraction: 0.8, cudaStackLimitBytes: 64 * 1024 * 1024})
  .debug({path: "build/ir", printIr: false, launchDebug: false, timeline: false})
  .build();
var configured = Context.fromOptions(opts);
var caps = configured.capabilities();
```

Small programs can use `quadrants.runtime.Runtime` as a default-session facade:

```haxe
Runtime.init(Arch.Cpu);
var ctx = Runtime.context();
Runtime.sync();
Runtime.reset();
```

`Runtime.init(...)` returns the active `Session`. `Runtime.reset()` closes the default session's context; any older `Session` returned by `Runtime.init(...)` is invalid after reset or reinitialization. `Runtime.stream()` and `Runtime.profiler()` are shortcuts for the default session's context.

## Core classes

| Haxe API | Purpose |
| --- | --- |
| `new Context(Arch.Cpu, enableProfiler = false)` / `Context.fromOptions(ContextOptions.create()...)` / `ContextOptions.builder()` | Create an explicitly owned Quadrants runtime context. `ContextOptions` applies the typed Haxe/HL setters currently backed by native APIs, records explicit warnings for parsed-but-not-yet-wired settings, and supports grouped builder configuration for offline cache, compile, default dtype, memory, AD, and debug sections. |
| `Runtime.init(Arch.Cpu, enableProfiler = false, options = null)`, `Runtime.context()`, `Runtime.sync()`, `Runtime.reset()` | Manage one default `quadrants.runtime.Session`; pass the same `ContextOptions` used by explicit contexts when a default session needs typed native-backed configuration. |
| `Context.sync()` / `Context.close()` | Synchronize queued work and release the native context. |
| `Context.supportsStreamEvents()` / `Context.isExtensionEnabled(Extension.MemoryProfiler)` / `Context.clearOfflineCache()` / `Context.fieldMirrorFallbacks()` / `Context.clearFieldMirrorFallbacks()` / `Context.capabilities()` / `Context.optionWarnings()` | Query typed runtime extensions, inspect explicit field-mirror fallback diagnostics, inspect the grouped capability schema, inspect parsed-but-not-yet-wired option warnings, and delete a previously configured offline-cache tree. |
| `new Tensor<I32>(ctx, [n])`, `new Tensor<F32>(ctx, [m, k])` | Allocate a primitive ndarray whose dtype is fixed by the generic type parameter. |
| `new Tensor<I32>(ctx, [])`, `TensorScalar.i32(ctx)` | Allocate a rank-0 scalar tensor containing exactly one element. |
| `Tensor<T>.fill(value)`, `read(i)`, `write(i, value)` | Typed flat host access. `read()` returns `T`; `write()` only accepts `T`. |
| `Tensor<T>.readAt(indices)`, `writeAt(indices, value)` | Typed multi-dimensional host indexing. |
| `Tensor<T>.scalarRead()`, `scalarWrite(value)` | Typed host and kernel scalar access for rank-0 tensors/fields. Use these instead of `tensor[0]` when the tensor shape is `[]`. |
| `Tensor<T>.toArray()` / `fromArray(values)` | Typed host-array transfer. |
| `Tensor<T>.readBytes(...)`, `writeBytes(...)`, `copyToBytes(...)`, `copyFromBytes(...)` | Raw byte transport for contiguous tensor ranges. |
| `Tensor<T>.view(flatStart, length)` / `BufferView<T>` | Checked flat view over a tensor. `BufferView<T>` kernel parameters flatten to tensor handle + start + length. |
| `Tensor<T>.grad`, `dual`, `enableGrad()` | Typed gradient/dual storage helpers. |
| `Tensor<T>.fromDLPack(...)`, `importDLPack(...)`, `fromExternalPointer(...)`, `importExternalPointer(...)` | Import typed tensors from contiguous DLPack capsules or external pointers on LLVM-backed backends. |
| `new Field<T>(ctx, shape)` / `new Field<T>(ctx)` plus `ctx.root...place(field)` / `FieldScalar.i32(ctx)` / `Field<T>.toTensor()` / `Field<T>.fromTensor(...)` | Typed SNode-backed field allocation, scalar/root placement, host access, tensor conversion, and tensor-to-field copies. Direct `Field<T>` kernel parameters bind the placed SNode; `field[i]`, scalar read/write, dynamic `append`/`length`, and pointer/bitmasked `isActive`/`activate`/`deactivate` lower to native field/SNode IR instead of mirror tensor copies. When a field is passed through an ndarray-only launch path, the context records a field-mirror fallback event instead of silently mirroring. |
| `Tensor<T>.supportsZeroCopy()`, `supportsDLPack()`, `supportsExternalPointerImport()`, `exportDLPack()`, `exportDevicePointer()` | Capability-probed interop helpers. DLPack exports must be closed by the caller. |
| `Kernel.build(ctx, macro (...) -> { ... }, {helpers: [MyHelpers]})` / `Kernel.buildRaw(ctx, macro (...) -> { ... }, {helpers: [MyHelpers]})` / `Template.build(DType.I32, ctx, macro (...:Tensor<TemplateDType>, ...) -> { ... })` | Build and JIT-compile a concrete kernel directly, optionally with explicit `@:qdFunc` helper classes, split between the compatibility `Kernel` facade and the low-level `KernelRaw` launch surface, or specialize one typed kernel template across dtypes. |
| `Kernel.descriptorBytes(..., {helpers: [MyHelpers]})` / `Template.descriptorBytes(...)` | Return QDHL descriptor bytes for tests/tooling. |
| `KernelRaw.launchDynamic(args)`, `launchBuffer(buf)`, `launchGraphDynamic(args)`, `launchGraphWhileDynamic(...)`, `launchGraphDoWhileDynamic(...)` | Low-level heterogeneous launch surface. New code should use this only for explicit dynamic boundaries or typed wrappers. |
| `Kernel.launch(args...)`, `launchGraph(...)`, `launchGraphWhile(...)`, `launchGraphDoWhile(...)` | Compatibility facade over `KernelRaw` for existing code. |
| `Kernel.launchRet(...)` / `launchRets(...)` | Compatibility facade for primitive scalar or fixed tuple returns. |
| `Kernel.grad()`, `forwardGrad()`, `validationKernel()` | Recompile the stored descriptor in reverse, forward, or validation autodiff mode. |
| `Context.stream()`, `Runtime.stream()`, `Context.setOfflineCache(...)`, `Context.setDebugDump(...)`, `Context.setRandomSeed(seed)` | Create execution streams and configure cache/debug-dump behavior. `setRandomSeed` also resets the native per-thread random states so later `rand*`/`SpecialOps.randn*` launches replay deterministically for the same seed. |
| `Stream.createEvent()` / `Stream.recordEvent(...)` / `Stream.waitEvent(...)` / `StreamEvent.sync()` | CUDA/AMDGPU stream-event coordination helpers. |
| `Context.profiler()`, `Runtime.profiler()`, `Profiler.recordKernel(...)`, `Profiler.printInfo(...)`, `Profiler.clearInfo(...)`, `quadrants.profiler.KernelProfiler`, `MemoryProfiler` | Runtime profiler queries by kernel name or kernel instance, print/clear convenience, typed CUPTI metric presets, and explicit memory-profiler availability probes. |
| `quadrants.algorithms.Reduce/Scan/Select/Sort/ReduceByKey`, `PrefixSumExecutor`, `Scratch` | Haxe-only scalar tensor algorithms for `I32`/`U32`/`I64`/`U64`/`F32`/`F64`: reduce add/min/max, exclusive add/min/max scans, stream compaction, simple sort/radix-sort entrypoints, reduce-by-key add, and reusable scratch storage. |
| `Tape.run(...)`, `Tape.withLoss(...)`, `Tape.withLossAndParams(...)`, `quadrants.ad.FwdMode.run(...)` | Tape lifecycle wrappers over explicit recording/replay, reverse-mode scalar-loss seed/clear helpers, and forward-mode dual seed/clear replay. |
| `quadrants.ad.Grad`, `GradCheck`, `CustomGradient` | Typed gradient/dual zeroing and seeding, finite-difference checking for F32 tensor/field inputs to a scalar loss, and explicit custom forward/backward kernel pairing. |
| `quadrants.coverage.Coverage`, `quadrants.compat.Diagnostics` | Kernel build/launch/source-span coverage JSON artifacts, descriptor dumps/hashes, value info, and runtime health checks. |
| `quadrants.packed.PackedVectorTensor/Field`, `PackedMatrixTensor/Field`, `StructOfArraysField`, `PackedStructTensor`, `PackedHelpers` | Workaround containers and kernel access helpers for logical vectors, matrices, and named struct members stored in primitive tensors/fields. |
| `VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, `MatrixField<T>`, `StructField` | First-class compound storage containers for flat AOS vector/matrix storage and SOA struct fields. Vector/matrix containers are kernel parameters and expose `readVec*` / `writeVec*` and `readMat*` / `writeMat*` lowering. |
| `FieldsBuilder.placeMany(...)`, `FieldsBuilder.finalize()`, `quadrants.snode.FieldPlacementPath`, `quadrants.snode.FieldTree`, `quadrants.runtime.LoopConfig` | Multi-field placement, reusable placement-path handles, lazy grad/dual field helpers, and centralized loop-control wrappers. |
| `quadrants.linalg.SparseMatrix<T>`, `SparseMatrixBuilder<T>`, `SparseSolver<T>`, `SparseCG`, `MatrixFreeCG<T>`, `MatrixFreeBICGSTAB<T>` | Typed F32/F64 host-reference sparse bridge with storage/solver/ordering enum abstracts, matrix ops, explicit host dense solver fallback, and matrix-free iterative solvers. |
| `quadrants.profiler.ProfilerBridge`, `ScopedProfiler` | Profiler feature probes and named scoped profiler blocks; scoped and kernel helpers expose print/clear parity. |
| `quadrants.perf.PerfDispatcher<TGeometry, TResult>` | Host-side typed perf dispatch utility with explicit registration, deterministic predicate selection, and cache keys/hits without decorators or public `Dynamic`. |
| `CompilerHints.assumeInRange(value, base, low, high)` | Lower a scalar expression to the native range-assumption IR node when the compiler supports it. |
| `SpecialOps.randnF32/F64`, `fnsU32`, `rawDiv/rawMod`, `frexpF32/F64`, `volatileLoad` | Typed kernel-only special/debug operations for Gaussian random values, find-nth-set-bit, truncating division/remainder, frexp decomposition, and volatile ndarray reads. |
| `Struct.decodeSchema({field: 0, nested: {value: 0}}, kernel.launchRets(...))` | Decode flattened struct returns back into nested Haxe object literals. |
| `Shared.array(DType.I32, size)` / `Shared.tile16(DType.F32)` | Generic shared-memory factories inside kernel bodies, alongside the dtype-specific `Shared.arrayI32(...)` / `Shared.tile16F32()` forms. |
| `CudaGlInterop.available(ctx)` / `CudaGlInterop.registerBuffer(ctx, glBuffer, byteSize)` | Query CUDA/OpenGL interop availability and register an OpenGL buffer with CUDA. |
| `CudaGlResource.map()` / `unmap()` / `dispose()` / `close()` | Map a registered OpenGL buffer to a CUDA device pointer, unmap after device writes, and unregister on cleanup. |

## Backend and dtype enums

```haxe
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.I32;
import quadrants.Types.F32;
```

`Arch` values are `Cpu`, `Cuda`, `Vulkan`, `Metal`, and `Amdgpu`.

`DType` values are `I8`, `I16`, `I32`, `I64`, `U8`, `U16`, `U32`, `U64`, `F16`, `F32`, `F64`, and `U1`.

`Extension` values are typed capability probes for `Context.isExtensionEnabled(...)`: `Cuda`, `CudaGlInterop`, `StreamEvents`, `KernelProfiler`, `ScopedProfiler`, `MemoryProfiler`, `ZeroCopy`, and `ExternalPointerImport`.

The dtype types in `quadrants.Types` are distinct abstracts, so `Tensor<I8>`, `Tensor<I16>`, and `Tensor<I32>` are different Haxe types even though their host representation is integer-like. `U32` and `U64` host values use `haxe.Int64` so the full unsigned range can pass through HashLink. `F32` uses `hl.F32` and accepts `Float` literals for host convenience.

## SIMT helper modules

`quadrants.simt` is a public helper-library layer built on `Shared`, `Block`, and `Subgroup`. Pass helper classes explicitly:

```haxe
var k = Kernel.build(ctx, macro (input:Tensor<I32>, out:Tensor<I32>) -> {
  blockDim(16);
  var lane = Block.threadIdx();
  var prefix = BlockScan.exclusiveAddI32Tile16(input[lane]);
  out[lane] = prefix;
}, {helpers: [BlockScan]});
```

The SIMT helper tranche provides `BlockReduce` (`reduceAdd/Min/Max` for I32/U32/I64/F32/F64, add-only U64, tile16 I32/F32 shortcuts, and `reduceAll/Any/CountI32` barrier votes), `BlockScan` (I32/F32 inclusive/exclusive add plus min/max scans), `SubgroupCompat` typed shuffle/broadcast wrappers including `shuffleXor*`, `broadcastFirst*`, active-mask and lane-mask helpers, `TileSort` tile16 I32 bitonic helpers, and typed tile utility classes (`Tile16x16F32/F64`, `Tile32x32F32/F64`). Tile utilities operate on explicit flat `Tensor<F32/F64>` tile storage such as `Shared.tile16F32()` or `Shared.arrayF32(1024)` and expose suffixed qdFunc entry points (`loadTile16x16F32`, `transposeTile16x16F32`, `choleskyTile16x16F32`, `solveTriangularTile16x16F32`, etc.) so helper names remain unambiguous. Ballot-style subgroup masks still require native descriptor ABI support; use `Grid.activeMask()`/`SubgroupCompat.activeMask()` for the existing active-lane primitive. These helpers require backends with the corresponding SIMT/shared-memory support; tests gate runtime execution to requested device backends and always keep descriptor coverage.

## Algorithms module

`quadrants.algorithms` derives the context from passed tensors. Reference `Reduce`, `Scan`, `Select`, and `Sort.parallelSort` support scalar `Tensor<I32>`, `Tensor<U32>`, `Tensor<I64>`, `Tensor<U64>`, `Tensor<F32>`, and `Tensor<F64>` where the operation is meaningful. Input/output dtype relationships are generic and typed: mismatched algorithm tensors fail during Haxe compilation instead of falling through to runtime dtype checks.

```haxe
var values = new Tensor<I32>(ctx, [4]);
var out = new Tensor<I32>(ctx, [4]);
values.fromArray([3, 1, 4, 2]);
Reduce.deviceReduceAdd(values, out);
Scan.deviceExclusiveScanAdd(values, out);
Sort.parallelSort(values);
var executor = new PrefixSumExecutor(ctx);
executor.deviceExclusiveScanAdd(values, out);
executor.close();
```

The same typed contract is used by `Select.deviceSelect<T>(input:Tensor<T>, flags:Tensor<I32>, output:Tensor<T>, countOut:Tensor<I32>, ?n)` and `ReduceByKey.deviceReduceByKeyAdd<T>(keys:Tensor<I32>, values:Tensor<T>, outKeys:Tensor<I32>, outValues:Tensor<T>, countOut:Tensor<I32>, ?n)`. `ReduceByKey.deviceReduceByKeyAdd` follows consecutive-run semantics: only adjacent equal keys are combined. The previous global grouping behavior is available as `ReduceByKey.reduceByKeyGlobalAdd` / `deviceReduceByKeyGlobalAdd`.

Typed entry points are also available for code that wants an explicit dtype in the call name, for example `Reduce.addU32`, `Reduce.maxF64`, `Scan.exclusiveAddI64`, `Select.selectU64`, and `Sort.sortF64`.

`Sort.deviceRadixSort` supports key-only I32/U32/I64/U64 radix reference sorting with optional `beginBit`/`endBit`. `Sort.deviceRadixSortPairs` preserves a scalar I32/U32/I64/U64/F32/F64 value tensor alongside I32/U32/I64/U64 keys and uses the same bit range semantics; signed key dtypes are transformed so full-range radix order matches signed numeric order.

| Algorithm family | CPU | CUDA/AMDGPU/Vulkan/Metal |
| --- | --- | --- |
| `Reduce.deviceReduceAdd/Min/Max` and typed `Reduce.add/min/max*` | Supported and tested for I32/U32/I64/U64/F32/F64 | Uses the same Haxe kernel path when the backend supports scalar loops; performance is a reference implementation. |
| `Scan.deviceExclusiveScanAdd/Min/Max`, typed `Scan.exclusive*`, and `PrefixSumExecutor` | Supported and tested for I32/U32/I64/U64/F32/F64 | Uses the same Haxe kernel path when the backend supports scalar loops; performance is a reference implementation. |
| `Select.deviceSelect` and typed `Select.select*` | Supported and tested for I32/U32/I64/U64/F32/F64 scalar tensors | Uses the same Haxe kernel path when the backend supports scalar loops; output order is stable. |
| `Sort.parallelSort` / `Sort.deviceRadixSort` / `Sort.deviceRadixSortPairs` | Supported and tested; radix keys are I32/U32/I64/U64 and pair values are I32/U32/I64/U64/F32/F64 | Uses simple deterministic kernels; intended as an API-stabilizing reference path, not a tuned device sort. |
| `ReduceByKey.deviceReduceByKeyAdd` | Supported and tested for I32 keys with I32/U32/I64/U64/F32/F64 values | Uses simple deterministic kernels; preserves consecutive key runs. |

The Haxe-only implementations are deterministic reference kernels intended for small/medium tensors and API stabilization. CPU is the always-tested backend. Device backends may run these kernels where the backend supports the required control flow, but performance portability is not the contract for this first tranche.

## First-class compound storage

Use `VectorNdarray` / `MatrixNdarray` for tensor-backed compound values and `VectorField` / `MatrixField` for field-backed compound values. They store primitive elements in a flat AOS layout and implement `TensorHandle`, so kernels can take them as direct parameters:

```haxe
var positions = VectorNdarray.f32(ctx, particleCount, 3);
positions.writeVec3(0, Vec3.f32(1.0, 2.0, 3.0));

var k = Kernel.build(ctx, macro (positions:VectorNdarray<F32>, out:Tensor<F32>) -> {
  var p = positions.readVec3(0);
  positions.writeVec3(0, Vec3.f32(p[0] + 1.0, p[1], p[2]));
  out[0] = p[0] + p[1] + p[2];
});
k.launch(positions, out);
```

`readVec2/3/4` and `writeVec2/3/4` lower to scalar loads/stores and produce normal kernel `Vector<T>` locals. `readMat2/3/4` and `writeMat2/3/4` do the same for row-major `Matrix<T>` locals. Host-side `read(...)`, `write(...)`, `toVectors()`, and `toMatrices()` are convenience wrappers over the same flat storage.

`StructField` is the first-class SOA struct container. String-keyed APIs remain available for compatibility, but new code should use `StructMember<T>` handles so member reads and writes keep value types in Haxe:

```haxe
var mass = new Field<F32>(ctx, [particleCount]);
var id = new Field<I32>(ctx, [particleCount]);
var massMember = new StructMember<F32>("mass");
var idMember = new StructMember<I32>("id");
var particles = new StructField()
  .addMember(massMember, mass)
  .addMember(idMember, id);
particles.writeMember(idMember, 0, 7);
```

Pass struct members (`particles.memberBy(massMember)`, etc.) to kernels when device code needs them; whole-struct kernel parameters remain deferred until the descriptor ABI has heterogeneous member metadata. Host code that needs typed whole-value movement can use `Struct.value1/2/3/4(...)` and `readValue*/writeValue*` on `StructField`, `StructOfArraysField`, and `PackedStructTensor`; these facades preserve member value types without exposing `Dynamic`. The old `add("name", value)`, `member("name")`, `read("name", i)`, and `write("name", i, value)` methods are compatibility shims and are listed in the retained-`Dynamic` ledger.

Migration from the Phase 6 workaround layer is explicit and lossless for the supported layouts:

```haxe
var packed = PackedVectorTensor.f32(ctx, particleCount, 3);
var positions = VectorNdarray.fromPacked(packed);
var packedAgain = positions.toPacked();
```

| Compound API | Storage layout | Kernel parameter support | Migration path |
| --- | --- | --- | --- |
| `VectorNdarray<T>` / `MatrixNdarray<T>` | Flat AOS primitive `Tensor<T>` storage. | Direct parameter; `readVec*` / `writeVec*` / `readMat*` / `writeMat*` lower to scalar IR. | `fromPacked(...)` / `toPacked()`. |
| `VectorField<T>` / `MatrixField<T>` | Flat AOS primitive `Field<T>` storage; placed fields synchronize through their tensor mirror before/after launch. | Direct parameter through `TensorHandle`; same compound read/write methods. | `fromPacked(...)` / `toPacked()`. |
| `StructField` | SOA: one placed primitive `Field<T>` per typed `StructMember<T>`. | Pass members as normal field parameters. | `fromStructOfArrays(...)` / `toStructOfArrays()`. |

Backend behavior: CPU runtime tests cover host storage, direct compound kernel parameters, placed field synchronization, and range-assumption lowering. CUDA/AMDGPU/Vulkan/Metal receive the same descriptor and native ndarray ABI when those backends support the underlying scalar tensor/field operations.

## Compiler hints

`CompilerHints.assumeInRange(value, base, low, high)` exposes the native range-assumption expression to Haxe kernels:

```haxe
var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
  var i = CompilerHints.assumeInRange(0, 0, 0, 1);
  out[0] = a[i];
});
```

`low` and `high` must be integer literals and `high > low`. The lowered expression is equivalent to `value` semantically; it gives the compiler the fact `base + low <= value < base + high`. Other proposed deep hints such as `blockLocal`, `cacheReadOnly`, and `noActivate` are not surfaced as public Haxe APIs until the runtime/compiler exposes a concrete per-kernel hook.

## Packed compound workaround layer

Use `quadrants.packed` when data is logically vector-, matrix-, or struct-shaped but final native compound storage is not required:

```haxe
var positions = PackedVectorTensor.f32(ctx, particleCount, 3);
positions.writeComponent(0, 0, 1.0);
positions.write(1, Vec3.f32(2.0, 3.0, 4.0));

var k = Kernel.build(ctx, macro (storage:Tensor<F32>, out:Tensor<F32>) -> {
  var p = PackedHelpers.readVec3F32(storage, 1);
  PackedHelpers.writeVec3F32(storage, 0, p);
  out[0] = p[0] + p[1] + p[2];
});
```

The workaround layout is deliberately explicit:

| Container | Host layout | Kernel helper behavior |
| --- | --- | --- |
| `PackedVectorTensor<T>` / `PackedVectorField<T>` | Flat primitive `Tensor<T>` / `Field<T>` storage with `length * components` elements; constructors also accept pre-existing typed storage whose trailing dimension matches `components`. | `PackedHelpers.readVec2/3/4I32/F32` and `writeVec2/3/4I32/F32` lower to flat scalar loads/stores. |
| `PackedMatrixTensor<T>` / `PackedMatrixField<T>` | Flat primitive `Tensor<T>` / `Field<T>` storage with `length * rows * cols` elements; constructors also accept pre-existing typed storage whose trailing dimensions match `rows, cols`. | `PackedHelpers.readMat2I32/F32`, `readMat3I32`, and `readMat4I32` lower to row-major scalar matrix locals. |
| `StructOfArraysField` | One primitive field per typed `StructMember<T>`, all placed with the same shape and context. | Pass the member field to kernels; `PackedHelpers.readMember*` / `writeMember*` lower to scalar loads/stores. |
| `PackedStructTensor` | One primitive tensor per typed `StructMember<T>`, all with the same shape and context. | Pass the member tensor to kernels; helper calls lower to scalar loads/stores. |

These names remain intentionally `Packed*` / `StructOfArrays*` for workaround code. Prefer `VectorNdarray`, `MatrixNdarray`, `VectorField`, `MatrixField`, and `StructField` for new first-class compound storage, use `StructMember<T>` handles for typed member access, and use the adapter methods when migrating existing packed code.

## FieldsBuilder, SNode helpers, and loop controls

`FieldsBuilder` can now place multiple fields through one path and freeze a reusable path handle:

```haxe
var a = new Field<I32>(ctx);
var b = new Field<I32>(ctx);
var path = ctx.root.dense(Axis.i, 1024).finalize();
path.placeMany([cast a, cast b]);
var grad = FieldTree.lazyFieldGrad(a);
```

Calling `finalize()` prevents further mutation of that builder until `destroy()` is called, but the returned `FieldPlacementPath` can keep placing compatible fields. `FieldTree.lazyFieldGrad(...)`, `lazyFieldDual(...)`, `lazyFieldGrads(...)`, and `lazyFieldDuals(...)` expose typed field gradient/dual allocation flows; the older `lazyGrad` / `lazyDual` names remain compatibility shims for heterogeneous field lists.

Loop controls are available either as the existing kernel DSL calls or through the central wrapper:

```haxe
var k = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
  LoopConfig.blockDim(128);
  LoopConfig.parallelize(4);
  LoopConfig.serialize();
  for (i in 0...out.shape(0)) out[i] = i;
});
```

Compiler-hint recipes remain explicit Haxe patterns: use `CompilerHints.assumeInRange(...)` for native range assumptions, `Shared.array*` / `Shared.tile16*` for manual shared-memory staging, `kernelRead`/`kernelWrite` in helper classes for flattened helper access, and tile load/store idioms built from `Block.threadIdx()` plus `Block.sync()`. In-kernel `StreamParallel.block(...)` and compiler-level `noActivate` remain explicit compile-time unsupported boundaries until the descriptor/backend has native lowering.

## Typed mesh and quant contracts

`quadrants.mesh` provides typed host-side handles for mesh domains, elements, relations, and attributes:

```haxe
var mesh = new Mesh(3, 0, 1);
var vertices = mesh.typedVertices();
var faces = mesh.typedFaces();
var v0 = vertices.get(0);
var f0 = faces.get(0);
var vertexToFace = mesh.relation(MeshKinds.vertex, MeshKinds.face);
vertexToFace.set(v0, [f0]);

var mass = new Field<I32>(ctx, [vertices.count()]);
var massAttr = mesh.attribute(MeshKinds.vertex, mass);
massAttr.write(v0, 7);
```

The relation handle type encodes the valid source and target domains, so passing an edge to a vertex-to-face relation is a compile-time error. This is currently a typed host contract; kernel-side mesh relation access, mesh attributes, and index-conversion lowering remain explicitly deferred until the native descriptor/bridge has typed relation metadata.

`quadrants.quant` provides typed storage descriptors, a Haxe-only reference quantized tensor, and native `quant_array` field placement for int/fixed specs:

```haxe
var spec = Quant.fixedF32(QuantBits.Bits8, QuantSignedness.Signed, 4);
var q = new QuantizedF32Tensor(ctx, [n], spec); // reference/debug utility
q.write(0, 1.5);
var raw:I32 = q.readRaw(0);

var field = new Field<F32>(ctx);
ctx.root.quantArray(Axis.i, n, QuantBits.Bits32).placeQuant(field, spec);
field.write(0, 1.5);
```

`QuantInt<Storage, Compute>`, `QuantFixed<Storage, Compute>`, and `QuantFloat<Storage, Compute>` carry storage/compute dtype metadata without public `Dynamic`. `QuantBits` is an enum abstract rather than an `Int`, so invalid bit-width parameters fail at compile time where Haxe can type-check them; constructor/runtime validation covers ranges such as fixed fractional bits. The HashLink bridge currently lowers `quantArray(...).placeQuant(...)` for int/fixed specs. `bitStruct(...)`, quant-float placement, and native quantized kernel parameters remain explicit unsupported boundaries and fail with typed errors instead of falling back to fake tensor semantics.

## Sparse/linalg and profiler bridge

`quadrants.linalg` is a native bridge namespace distinct from any host-only helper types:

```haxe
var builder = new SparseMatrixBuilder<F32>(ctx, 2, 2, DType.F32, SparseStorageFormat.CSR, 4);
builder.set(0, 0, 4.0).set(0, 1, 1.0).set(1, 0, 1.0).set(1, 1, 3.0);
var matrix = builder.build();
var b = new Tensor<F32>(ctx, [2]);
var x = new Tensor<F32>(ctx, [2]);
b.fromArray([1.0, 2.0]);
new SparseSolver<F32>(ctx, DType.F32, SparseSolverType.LU, SparseOrdering.COLAMD, true).solve(matrix, b, x);
SparseCG.solve(matrix, b, x, 32, 1.0e-5);
```

`SparseBackendFeatures.probe(ctx)` reports the current bridge as `SparseBackendKind.HostReference`: sparse values are stored in the native HashLink handle, F32/F64 matvec and CG are implemented by host/reference loops, and direct solve uses the existing dense host fallback only when `allowHostDenseFallback` is passed as `true` to `SparseSolver<T>`. CUDA/other device contexts therefore do not imply a GPU sparse backend.

| Bridge feature | CPU | CUDA/other device backends |
| --- | --- | --- |
| `SparseMatrix<T>` / `SparseMatrixBuilder<T>` F32/F64 insertion, get, clear, `nnz`, `matVec`, `transpose`, `add`, `sub`, and small matrix `mul` | Supported and runtime-tested through the host-reference bridge. | Feature probe reports host-reference storage; no GPU sparse storage is synthesized. |
| `SparseSolver<T>` with `SparseSolverType.LLT/LDLT/LU` and `SparseOrdering.AMD/COLAMD/Natural` | Supported for F32/F64 small square systems only through explicit `allowHostDenseFallback=true`. | Native GPU sparse solver support is reported unavailable; fallback remains host dense and explicit. |
| `SparseCG.solve`, `MatrixFreeCG<T>`, `MatrixFreeBICGSTAB<T>` | Supported and runtime-tested for F32/F64 sparse CG and F32 matrix-free convergence/failure paths. | Uses host-reference tensor reads/writes unless the native bridge later reports a native sparse backend. |
| `ProfilerBridge.features`, `ScopedProfiler.run`, `Profiler.clearInfo`, `KernelProfiler.printInfo` | Supported and runtime-tested with profiler-enabled CPU context. | Feature probes report availability from the native bridge. CUPTI metric presets are typed Haxe values; applying them returns `false` unless the native backend/toolkit accepts them. |
| `MemoryProfiler.probe` / `MemoryProfiler.printInfo` | Returns an explicit typed unavailable status. | The HashLink native bridge currently reports memory profiling as unavailable; no fake memory-profiler data is synthesized. |

`ProfilerBridge.features(ctx)` returns `enabled`, `scoped`, `memory`, and `kernel` booleans. `MemoryProfiler.probe(ctx)` returns a `MemoryProfilerStatus` whose `availability` is `ProfilerAvailability.Unavailable` until the native HashLink bridge exposes a real memory-profiler surface.

Use `CuptiMetric.preset(CuptiMetricPreset.GlobalAccess)` or other `CuptiMetricPreset` enum values for built-in profiler metric lists instead of passing raw metric-name strings through public APIs.

## Perf dispatch host utility

`PerfDispatcher<TGeometry, TResult>` is a Haxe host utility for autotuning-style selection without Python decorators. Geometry is caller-defined and typed; each candidate has a non-empty name, a typed predicate over that geometry, and a typed builder function:

```haxe
import quadrants.Types.Arch;
import quadrants.perf.PerfDispatchContext;
import quadrants.perf.PerfDispatcher;

class Geometry {
  public final n:Int;
  public function new(n:Int) this.n = n;
}

var dispatcher = new PerfDispatcher<Geometry, String>(
  function(g) return 'n=${g.n}',
  "example-kernels"
);
dispatcher.register("small", function(g) return g.n <= 1024, function(g, ctx) return "small-kernel");
dispatcher.register("fallback", function(g) return true, function(g, ctx) return "fallback-kernel");

var selection = dispatcher.select(new Geometry(512), new PerfDispatchContext(Arch.Cpu, "fast-math=0"));
var kernelName = selection.result;
```

Selection is deterministic: candidates are evaluated in registration order and the first matching predicate is chosen. The cache key is explicit (`cacheKey(geometry, arch, compileOptions)`) and includes the dispatcher's namespace, backend arch, compile-option string, and the caller-provided geometry key. Successful selections are cached in memory; failed candidate builders are not cached, so a transient compile failure does not poison later selection. When a builder needs a typed Quadrants `Context`, capture that context in the candidate closure and keep `PerfDispatchContext` for the arch and compile options that affect dispatch.

## Autodiff workflow and diagnostics

Tape lifecycle helpers keep recording explicit. Use `Tape.withLoss` when the tape represents a scalar F32 loss: it clears recorded adjoints, seeds `loss.grad` to `1.0`, replays reverse mode, and can clear the tape after replay.

```haxe
var tape = Tape.withLoss(loss, function(tape) {
  tape.launch(lossKernel, x, loss, n);
}, true);
```

Use `Tape.withLossAndParams(loss, params, body, clearAfter)` when parameters that are not part of the recorded launch arguments must also be cleared before the reverse pass.

`quadrants.ad.FwdMode.run(param, loss, seed, body, clearAfter)` records the body, clears recorded duals and the output dual, fills `param.dual` with `seed`, and replays forward mode:

```haxe
var tape = FwdMode.run(x, loss, 1.0, function(tape) {
  tape.launch(lossKernel, x, loss, n);
}, true);
```

Reverse/validate kernels no longer receive an extra Haxe-side rejection solely because their descriptor contains `while`, `break`, or `continue`; native descriptor validation/runtime support is authoritative for those dynamic-control-flow cases.

`GradCheck.checkTensorToScalar(kernel, args, input, loss)` compares reverse-mode gradients with central finite differences for F32 tensor inputs and a one-element F32 loss tensor. `checkTensorsToScalar`, `checkFieldToScalar`, and `checkFieldsToScalar` cover multiple tensor parameters and F32 fields; mismatches report the parameter name, flat index, analytic value, numeric value, and absolute/relative errors. `CustomGradient` pairs caller-provided forward/backward kernels for explicit tape recording; it does not emulate Python decorators.

`Grad.zeroGrad`, `zeroDual`, and `clearAllGradients` remain heterogeneous compatibility helpers. Prefer `zeroTensorGrad`, `zeroFieldGrad`, `zeroTensorDual`, `zeroFieldDual`, `seedTensorGrad`, `seedFieldGrad`, `seedTensorDual`, and `seedFieldDual` when the value kind is statically known.

`Coverage.enable()` records kernel builds, launches, and descriptor source-span probe counts. `Coverage.flush(path)` writes JSON artifacts. `Diagnostics.descriptorDump(kernel)`, `Diagnostics.kernelInfo(kernel)`, `Diagnostics.valueInfo(value)`, and `Diagnostics.health(ctx)` are host-side inspection helpers.

## Primitive bulk byte transfers

Use `Tensor<T>.readBytes(out, flatStart, count, outByteOffset = 0)` and `writeBytes(input, flatStart, count, inputByteOffset = 0)` to copy raw little-endian primitive values. `copyToBytes` and `copyFromBytes` default to the whole tensor. Typed byte wrappers such as `readI32Bytes` and `readF32Bytes` were removed; the tensor dtype is already fixed by `T`.

```haxe
var positions = new Tensor<F32>(ctx, [particleCount, 3]);
var bytes = new hl.Bytes(particleCount * 3 * 4);
positions.readBytes(bytes, 0, particleCount * 3);
var x0 = bytes.getF32(0);
```

## Field placement

`Field<T>` uses the same generic dtype binding as `Tensor<T>`. `new Field<I32>(ctx, [n])` creates a dense placed field, while `new Field<I32>(ctx)` can be placed explicitly through the context root:

```haxe
var flags = new Field<U1>(ctx);
ctx.root.pointer(Axis.i, 8).bitmasked(Axis.i, 4).place(flags);
flags.write(3, true);
var asTensor:Tensor<U1> = flags.toTensor();
```

Host `read`, `write`, `fill`, `toArray`, `fromArray`, `grad`, `dual`, and `toTensor()` remain typed by `T`. In kernels, an explicitly annotated `Field<T>` parameter is a direct SNode argument: ordinary indexing reads/writes field storage, dynamic nodes support `append(indexPrefix, value)` and `length(indexPrefix)`, and pointer/hash/bitmasked nodes support `isActive(index)`, `activate(index)`, and `deactivate(index)`. Launch validates that the field is placed and that the launched SNode topology supports the operation. Use `toTensor()` / `fromTensor(...)` when a tensor mirror is required for host interop.

## Interop import/export

Use capability probes before exporting raw interop handles or importing external storage:

```haxe
var t = new Tensor<F32>(ctx, [2, 3]);
if (t.supportsZeroCopy()) {
  var ptr:haxe.Int64 = t.exportDevicePointer();
  var alias = Tensor<F32>.fromExternalPointer(ctx, ptr, [2, 3]);
}
if (t.supportsDLPack()) {
  var dlpack = t.exportDLPack();
  try {
    var ndim = dlpack.ndim();
    var data = dlpack.dataPointer();
    var imported = Tensor<F32>.fromDLPack(ctx, dlpack);
    imported.write(0, 7.0);
  } finally {
    // `fromDLPack` / `importDLPack` consume the handle on success.
    if (dlpack != null) dlpack.close();
  }
}
```

`DLPackTensor` exposes device, dtype, shape, stride, and data-pointer metadata for exported tensors. `Tensor<T>.fromDLPack(...)` and `importDLPack(...)` accept contiguous row-major primitive tensors whose DLPack dtype exactly matches `T`. `Tensor<T>.fromExternalPointer(...)` and `importExternalPointer(...)` wrap an existing device/host pointer with the current context and shape. Exported DLPack tensors and device pointers alias storage owned by the source tensor, so keep the source tensor and context alive until every consumer of that alias is finished.

`supportsExternalPointerImport()` is currently true only for LLVM-backed contexts (`Cpu`, `Cuda`, and `Amdgpu`). Vulkan and Metal still do not expose external-pointer or DLPack-import paths through the HashLink bridge.

## CUDA/OpenGL interop

The `CudaGlInterop` and `CudaGlResource` classes allow a HashLink renderer to share OpenGL buffers with CUDA kernels without a host-side copy. This requires `Arch.Cuda` and a `quadrants.hdll` built with `QD_WITH_CUDA=ON` and the CUDA toolkit found by CMake.

```haxe
import quadrants.Context;
import quadrants.CudaGlInterop;
import quadrants.CudaGlResource;
import quadrants.Types.Arch;

var ctx = new Context(Arch.Cuda);
if (!CudaGlInterop.available(ctx)) {
  throw "CUDA/GL interop is not available on this context";
}

// Register an OpenGL buffer (e.g. hlsdl's sdl.GL.Buffer) with CUDA.
var resource = CudaGlInterop.registerBuffer(ctx, glBuffer, byteSize);

// Map for device writes, write via a Tensor obtained from the pointer, then unmap.
var devicePtr:haxe.Int64 = resource.map();
// ... launch a kernel that writes to devicePtr ...
resource.unmap();

// Release the registration when the OpenGL buffer is no longer needed.
resource.dispose();
```

`CudaGlInterop.available(ctx)` returns `true` only when the native bridge was built with CUDA and the context backend is `Cuda`. On non-CUDA builds it returns `false` and does not throw.

`CudaGlInterop.registerBuffer(ctx, glBuffer, byteSize)` registers an OpenGL buffer object with CUDA. The `glBuffer` parameter is typed `Dynamic` so Quadrants does not depend on hlsdl; hlsdl's `sdl.GL.Buffer` can be passed directly. `byteSize` must be positive.

`CudaGlResource` holds the registration and must stay alive for as long as the mapped device pointer is in use. `map()` returns a `haxe.Int64` CUDA device pointer; `unmap()` releases it after device writes are finished and is safe to call when already unmapped; `dispose()` unregisters the resource and cleans up. `close()` is an alias for `dispose()`. Calling `dispose()` or `close()` on a mapped resource implicitly unmaps it first in the native bridge.

## Python binding migration map

| Former Python binding | Haxe/HL equivalent |
| --- | --- |
| `import quadrants as qd` | `import quadrants.Context; import quadrants.Kernel; import quadrants.runtime.Runtime; import quadrants.Types.Arch;` |
| `qd.init(arch=qd.cpu)` | `Runtime.init(Arch.Cpu);` for a default session, or `var ctx = new Context(Arch.Cpu);` for explicit ownership. |
| `qd.cpu`, `qd.cuda`, `qd.vulkan`, `qd.metal`, `qd.amdgpu` | `Arch.Cpu`, `Arch.Cuda`, `Arch.Vulkan`, `Arch.Metal`, `Arch.Amdgpu` |
| `qd.ndarray(qd.i32, shape=(n,))` | `new Tensor<I32>(Runtime.context(), [n])` or `new Tensor<I32>(ctx, [n])` |
| `@qd.kernel def f(...): ...` | `var k = Kernel.build(ctx, macro (...) -> { ... });` |
| `f(a, b, n)` | `k.launch(a, b, n);` |
| `qd.sync()` | `Runtime.sync();` or `ctx.sync();` |
| Python host indexing (`a[i]`, `a.to_numpy()`) | `read`, `write`, `readAt`, `writeAt`, `toArray`, `fromArray`, or raw bytes. |

## Current feature boundary

The Haxe/HashLink binding supports primitive typed ndarrays, typed SNode-backed fields and placement, native `quantArray(...).placeQuant(...)` field placement for int/fixed quant specs, scalar kernel arguments, basic control flow, n-dimensional range loops, static mesh-for over `Mesh.forVertices/forEdges/forFaces/forCells(literalCount)`, inline `@:qdFunc` helpers from the local class or explicit `Kernel.build(..., {helpers: [...]})` helper libraries, `quadrants.simt` helper classes, Haxe-only `quadrants.algorithms` reference kernels for scalar I32/U32/I64/U64/F32/F64 tensors, template-specialized kernels via `Template.build(...)`, struct/vector/matrix kernel locals, flattened struct returns decoded with `Struct.decodeSchema(...)`, typed compound storage, typed host mesh relation/attribute handles, typed quant descriptors with Haxe-only reference storage, generic or dtype-specific shared-memory factories, typed host perf dispatch with explicit cache keys, native backend selection, primitive scalar and tuple return values, streams, stream events on CUDA/AMDGPU, graph launches including `launchGraphWhile(...)`, profiler queries, offline-cache toggles and clearing, IR/debug-dump configuration, a default runtime/session facade, native autodiff kernel build modes plus tape/grad-check/custom-gradient workflow helpers, kernel build/launch coverage artifacts, diagnostics helpers, CUDA/OpenGL interop via `CudaGlInterop` and `CudaGlResource`, and zero-copy / external-pointer / DLPack interop on LLVM-backed backends.

Not yet exposed through the Haxe API: Python package modules, mesh relation/attribute access inside kernels, `bitStruct` quant placement, quant-float placement, quantized kernel parameters, in-kernel stream-parallel lowering, NumPy/PyTorch import, GUI/window interop, and Python decorators.

Use [Haxe kernel language](kernel_language.md) for the exact macro-supported syntax and [Haxe/HashLink integration](hashlink.md) for build and packaging details.
