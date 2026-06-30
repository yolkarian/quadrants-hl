# HashLink public Dynamic boundary ledger

HashLink treats `Dynamic` as an interop boundary, not a normal public API design tool. Public APIs that can express dtype or storage-kind relationships use typed generics (`Tensor<T>`, `Field<T>`, `VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, `MatrixField<T>`, `StructMember<T>`).

| API surface | Classification | Retention reason |
| --- | --- | --- |
| `KernelRaw.launchDynamic(...)`, `launchOnDynamic(...)`, graph launch methods, `launchRetDynamic(...)`, `launchRetsDynamic(...)`, `kernel.ArgBuffer`, and native `hl.NativeArray<Dynamic>` launch bridge | Permanent necessary boundary | Runtime kernel calls accept heterogeneous argument lists whose arity and scalar/tensor mix are determined by the compiled descriptor. |
| `TapeRecord.args` and `Tape.recordKernel(...)` / `Tape.recordCustom(...)` internal replay hooks | Internal necessary boundary | Typed `QKernelN.launchTape(...)` records heterogeneous launch values for reverse/forward replay without exposing `Tape.launch(...Dynamic)` as the user entrypoint. |
| `GradCheck.check*ToScalar(..., args:Array<Dynamic>, ...)` | Permanent necessary boundary | Grad checking replays a kernel with the same heterogeneous launch argument list while separately identifying typed differentiable inputs and scalar loss. |
| `Native.kernel_launch*`, `Native.kernel_launch*_specialized`, `Native.kernel_launch_ret(s)` | Permanent necessary boundary | HashLink native ABI passes descriptor-validated heterogeneous runtime values and specialization values through `hl.NativeArray<Dynamic>` at the explicit bridge boundary. |
| `catch (e:Dynamic)` cleanup paths | Permanent necessary boundary | Haxe exception values are dynamic; cleanup must rethrow the original value. |
| `Coverage.snapshot()` and `Diagnostics.descriptorDump/kernelInfo/valueInfo/health(...)` | Permanent necessary boundary | These intentionally return JSON-like anonymous objects for tooling. |
| `Profiler.traceEvents()` and `Profiler.memoryStats()` | Permanent necessary boundary | Profiler timelines and memory summaries are backend-defined JSON-like tool artifacts. |
| `CudaGlInterop.registerBuffer(..., glBuffer:Dynamic, ...)` and native CUDA/GL registration | Permanent necessary boundary | Avoids forcing the Haxe package to depend on hlsdl while still accepting hlsdl GL buffer objects. |
| Helper registry class lists using `Class<Dynamic>` | Permanent necessary boundary | Haxe class values for heterogeneous helper classes require dynamic class storage. |
| `Struct.ofN(...)` kernel-only marker return values | Permanent macro boundary | These values are compile-time DSL markers consumed by `KernelBuilder`, not runtime data APIs. |
| Descriptor macro builders (`TypeTableBuilder`, `ArgTableBuilder`, `ResourceTableBuilder`, `StructTableBuilder`, `DescriptorWriter`) | Permanent macro boundary | Build macros assemble normalized descriptor metadata as anonymous JSON-like objects; the data does not cross the user runtime API as typed resources. |
| `StructTensor.__create(...)` and `StructTensor.descriptorResource()` | Internal/descriptor boundary | QdStruct allocation passes generated schema metadata and descriptor-resource snapshots through JSON-like values. User-facing member access remains typed by dtype-specific tensors where possible. |
| `StructField.add/member/read/write`, `StructOfArraysField.add/member/read/write`, `PackedStructTensor.add/member/read/write` | Compatibility shim | String-keyed heterogeneous struct containers erase member types. New code should use `StructMember<T>` plus `addMember`, `memberBy`, `readMember`, and `writeMember` or dtype-specific member tensors/fields. |
| `Grad.zeroGrad`, `zeroDual`, `clearAllGradients` | Compatibility shim | These preserve heterogeneous tensor/field utility calls. New code can use `zeroTensorGrad`, `zeroFieldGrad`, `zeroTensorDual`, and `zeroFieldDual`. |
| `FieldTree.lazyGrad/lazyDual/lazyGrads/lazyDuals` and `FieldPlacementPath.lazyGrad/lazyDual` | Compatibility shim | These preserve heterogeneous field-tree helpers. New code can use `lazyFieldGrad`, `lazyFieldDual`, `lazyFieldGrads`, and `lazyFieldDuals`. |

Removed public `Dynamic` surfaces:

- `Kernel.launch(...)`, `Kernel.launchOn(...)`, `Kernel.launchRet(...)`, `Kernel.launchRets(...)`, and dynamic graph launch helpers were removed from the public `Kernel` facade. Use typed `Kernel.build(...)` wrappers or explicit `KernelRaw` for low-level bridge work.
- `Tape.launch(...)` and `Tape.launchCustom(...)` were removed. Use typed `QKernelN.launchTape(tape, ...)`.
- Algorithms now type input/output dtype relationships with `Tensor<T>`.
- `PrefixSumExecutor` scan methods now type input/output dtype relationships with `Tensor<T>`.
- Vector/matrix ndarray and field wrappers now store `Tensor<T>` or `Field<T>` instead of `Dynamic`.
- Packed vector/matrix wrappers now store `Tensor<T>` or `Field<T>` instead of `Dynamic`.
- `PackedHelpers.writeMat2I32/F32` now accept typed `Matrix<I32/F32>` values.
- `TensorRuntime` and `FieldRuntime` peer storage fields now use `TensorHandle`, `FieldRuntime`, or `TensorHandle` instead of public `Dynamic`.
- `Ndrange.of(...)` and `Ndrange.ranges(...)` compatibility markers now return the typed `NdrangeDomain` marker instead of `Dynamic`; the preferred APIs remain `of1`/`of2`/`of3`/`of4` and `ranges1`/`ranges2`/`ranges3`/`ranges4`.

Compatibility policy:

- Permanent necessary boundaries are allowed to stay public and must not be used as precedent for new ordinary APIs.
- Compatibility shims may stay for migration, but new docs and examples should show the typed alternative first.
- A compatibility shim can be deprecated only when the typed replacement has runtime coverage, compile-fail coverage for the static guarantee, and a migration example.
- Any new public `Dynamic` must add a row to this ledger in the same change.
- `tools/check_public_dynamic.sh` enforces that new public `Dynamic` surfaces are explicitly allowlisted.
