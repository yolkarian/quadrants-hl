# Haxe kernel language

Quadrants kernels are written as Haxe macro arrow functions and passed to `Kernel.build`. They are not arbitrary Haxe functions: the macro accepts a deliberately small DSL that can be lowered to Quadrants IR and rejects unsupported constructs at Haxe compile time.

```haxe
var k = Kernel.build(ctx, macro (a, b, out, n) -> {
  for (i in 0...n) {
    var x = a[i] + b[i];
    if (x > 0) {
      out[i] = x;
    } else {
      out[i] = -x;
    }
  }
});
```

## Parameters

Kernel parameters may be primitive scalars, `Tensor<T>` ndarrays, direct `Field<T>` SNode fields, or one-dimensional `BufferView<T>` views. If an untyped parameter is used as `a[i]`, it is inferred as an ndarray; otherwise it is inferred as a scalar. Annotate fields explicitly as `Field<T>` when the kernel should bind the placed SNode instead of the tensor-ABI mirror.

```haxe
import quadrants.Tensor;
import quadrants.Types.F32;

var k = Kernel.build(ctx, macro (a:Tensor<F32>, out:Tensor<F32>, n:Int, scale:F32) -> {
  for (i in 0...n) {
    out[i] = a[i] * scale;
  }
});
```

An ndarray parameter must be used with one consistent rank. Direct nested indexing is supported up to rank 8:

```haxe
out[i][j] = a[i][j] + 1;
```

A `BufferView<T>` kernel parameter is flattened at launch to the underlying tensor handle plus its checked flat start and length. `view[i]` lowers to `tensor[view.flatStart + i]`, and `view.shape(0)` returns the view length.

`Field<T>` parameters lower to native field expressions. `field[i]` reads/writes the placed SNode directly, and launch passes the field's SNode id instead of copying through the tensor mirror. Dynamic fields expose `field.append(indexPrefix, value)` and `field.length(indexPrefix)` in kernels; pointer/hash/bitmasked fields expose `field.isActive(index)`, `field.activate(index)`, and `field.deactivate(index)`. The native specialization validates that the launched field placement supports the requested SNode operation.

## Supported statements

- Blocks.
- Local variable declarations and assignments with block, loop, and branch scope.
- `for (i in start...end)` range loops.
- `for (I in Ndrange.of2(a, b))` and the other typed `Ndrange.of1`/`of3`/`of4` helpers for one- to four-dimensional nested range loops from zero, or `Ndrange.ranges2(begin0, end0, begin1, end1)` and the other typed `rangesN` helpers for explicit begin/end pairs; use `I[0]`, `I[1]`, ... inside the body.
- `Ndrange.of2Axes(a, b, AxisOrder.of2(1, 0))` and `rangesNAxes(...)` variants to change iteration nesting order. The `AxisOrder.ofN(...)` arguments are canonical axis indices listed outermost first and must be a permutation of `0...N`; yielded `I[axis]` values remain in canonical axis order.
- `for (i in fieldOrTensor)` or `for (i in Grouped.of(fieldOrTensor))` struct-for over a direct `Field<T>` or `Tensor<T>` parameter. `Grouped.of(Ndrange.of3Axes(...))` supports the same typed ndrange domains and axis order controls.
- `for (i in Static.range(begin, end))` static loops over integer literals; `Static.value(literal)` can wrap compile-time literal constants used in static bounds or expressions.
- `for (v in Mesh.forVertices(count))`, `Mesh.forEdges(count)`, `Mesh.forFaces(count)`, or `Mesh.forCells(count)` static mesh-for over a non-negative integer literal count. Current kernel mesh-for support covers loop indices only. `quadrants.mesh.MeshRelation` / `MeshAttribute` kernel parameters are rejected at compile time because the QDHL descriptor does not yet carry typed mesh resource metadata for native relation/index-conversion lowering.
- `while` loops.
- `break` and `continue` inside loops.
- `if` / `else` statements. Literal `if (true)` / `if (false)` and `if (Static.value(trueOrFalse))` conditions are expanded at macro time.
- Ndarray and field element assignment, vector/matrix component assignment, and struct-field assignment for kernel locals.
- Atomic compound assignment (`+=`, `-=`, `*=`, `&=`, `|=`, `^=`) on ndarray elements. Use `atomicAdd(a[i], value)` and related atomic calls when the old value is needed.
- Loop scheduling hints before the loop they decorate: `blockDim(n)`, `parallelize(n)`, and `serialize()`. The same lowered hints are available through `quadrants.runtime.LoopConfig.blockDim(...)`, `parallelize(...)`, and `serialize()`.
- `print(valueOrLiteral)` and `assert(condition, "message")` frontend statements.
- `return;` with no value, primitive scalar `return value;` launched through `Kernel.launchRet(...)`, fixed primitive tuple returns written as `return [a, b, ...];`, and flattened vector/matrix/struct local returns launched through `Kernel.launchRets(...)`. Struct locals may contain previously declared struct locals; nested field access uses `outer.inner.field`.

## Local scopes

Local names follow lexical scopes created by blocks, `if` / `else` bodies, `while` bodies, and `for` bodies. A nested scope may shadow an outer local, and assignments update the nearest visible local.

```haxe
var k = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
  var x = 1;
  {
    var x = 7;
    out[0] = x; // 7
  }
  out[1] = x; // 1
});
```

Kernel parameters may not be shadowed by locals. Re-declaring the same local name in one scope is rejected.

## Supported expressions

- Integer and floating-point literals.
- Scalar parameter and local variable loads.
- Ndarray and `BufferView` element loads.
- Arithmetic: `+`, `-`, `*`, `/`, `%`.
- Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`.
- Boolean logic: `&&`, `||`, `!`.
- Integer bitwise ops: `&`, `|`, `^`, `<<`, `>>`, `>>>`, `~`.
- Unary negation: `-x`.
- Expression-level `if`: `if (cond) a else b`, and Haxe ternary `cond ? a : b`.
- Explicit casts/check types to supported primitive dtypes, plus `bitCast(x, "I32")` or another dtype name for bit-preserving casts.
- `CompilerHints.assumeInRange(value, base, low, high)` lowers to the native range-assumption expression and returns `value` semantically; `low` and `high` must be integer literals with `high > low`.
- Math calls: `abs`, `sin`, `asin`, `cos`, `acos`, `tan`, `atan`, `tanh`, `exp`, `log`, `sqrt`, `rsqrt`, `floor`, `ceil`, `round`, `min`, `max`, `atan2`, `pow`, `inv`, `rcp`, `popcnt`, `clz`, `ffs`, `sgn`, `isnan`, `isinf`, and `select(cond, a, b)`.
- Special ops from `quadrants.SpecialOps`: `randnF32()` / `randnF64()` use the same deterministic random stream as `randF32` / `randF64`; `fnsU32(mask, base, offset)` returns the bit index of the offset-th set bit from `base` or `0xffffffff`; `rawDiv(lhs, rhs)` and `rawMod(lhs, rhs)` expose truncating native integer division/remainder; `frexpF32/F64(x)` returns a kernel struct with `.significand` and `.exponent` (AMDGPU currently rejects this HashLink form explicitly); `volatileLoad(tensor[i])` emits a volatile ndarray load on LLVM-backed backends and is rejected for unsupported backends/forms.
- Random scalar calls: `randI32()`, `randU32()`, `randF32()`, and `randF64()`.
- Atomic fetch operations: `atomicAdd`, `atomicSub`, `atomicMul`, `atomicMin`, `atomicMax`, `atomicAnd`, `atomicOr`, `atomicXor`, `atomicExchange`, and `atomicCompareExchange(target, expected, desired)` on ndarray elements return the previous value.
- `shape(tensor, axis)` or `tensor.shape(axis)` returns a tensor/field parameter's runtime extent along a literal axis.
- Vector locals from `Vec2`/`Vec3`/`Vec4` factories or `Vector.ofArray([...])`, with component/index access, elementwise arithmetic, `dot`, `cross`, `norm`, `normalized`, and `outer` lowering to scalar IR.
- Matrix locals from `Mat2`/`Mat3`/`Mat4` factories or `Matrix.ofArray(rows, cols, [...])`, with constant row/column indexing, elementwise arithmetic, `matmul`, `matvec`/`multiplyVector`, `transpose`, `trace`, `determinant`, `inverse` (F32/F64 matrices only), `frobeniusSquared`, `frobeniusNorm`, `diagonal`, `Matrix.diag(vector)`, and `Matrix.outer(lhs, rhs)` lowering to scalar IR for sizes up to 4x4.
- `VectorNdarray<T>` / `VectorField<T>` parameters support `readVec2/3/4(index)` and `writeVec2/3/4(index, value)`, lowering to flat scalar loads/stores over first-class compound storage.
- `MatrixNdarray<T>` / `MatrixField<T>` parameters support `readMat2/3/4(index)` and `writeMat2/3/4(index, value)`, lowering to row-major scalar matrix loads/stores.
- Shared local arrays from `Shared.arrayI8/I16/I32/I64/U8/U16/U32/U64/U1/F16/F32/F64(size)` or `Shared.array(DType.I32, size)`, plus fixed 16x16 tiles from the matching `Shared.tile16*()` or `Shared.tile16(DType.F32)` factories, with normal `shared[i]` indexing inside kernels.
- Struct locals from `Struct.ofN("field", value, ...)` or object literals such as `{mass: value, velocity: value + 1}`, with scalar/nested struct fields, field reads, and field assignment/compound assignment.
- `Grid.threadIdx()` returns the backend linear thread index for the current lowered loop.
- SIMT helpers: `Block.threadIdx()`, `Block.barrierAnd(value)`, `Block.barrierOr(value)`, `Block.barrierCount(value)`, `Subgroup.size()`, `Subgroup.invocationId()`, `Subgroup.elect()`, `Subgroup.shuffle(value, lane)`, `Subgroup.shuffleUp(value, delta)`, `Subgroup.shuffleDown(value, delta)`, `Subgroup.broadcast(value, lane)`, `Workgroup.localInvocationId()`, `Workgroup.globalInvocationId()`, `Grid.activeMask()`, and `Grid.vkGlobalThreadIdx()`. `quadrants.simt` adds typed block reductions/scans, `SubgroupCompat.shuffleXor*/broadcastFirst*/laneMask*`, and explicit tile qdFuncs for 16x16/32x32 F32/F64 flat tile storage.
- Packed workaround helper calls from `quadrants.packed.PackedHelpers` for flat primitive storage: `readVec2/3/4I32/F32`, `writeVec2/3/4I32/F32`, `readMat2I32/F32`, `readMat3I32`, `readMat4I32`, and `readMember*/writeMember*` lower to scalar tensor loads/stores and produce normal vector/matrix/scalar kernel locals.

## Dtypes in annotations and casts

The macro recognizes these type names in scalar annotations, `Tensor<T>` parameters, and casts:

| Haxe type | Quadrants dtype |
| --- | --- |
| `Int`, `quadrants.Types.I32` | `i32` |
| `haxe.Int64`, `quadrants.Types.I64` | `i64` |
| `UInt`, `quadrants.Types.U32` | `u32` |
| `Bool`, `quadrants.Types.U1` | `u1` |
| `quadrants.Types.I8`, `I16`, `U8`, `U16`, `U64` | matching integer dtype |
| `quadrants.Types.F16` | `f16` |
| `hl.F32`, `quadrants.Types.F32` | `f32` |
| `Float`, `quadrants.Types.F64` | `f64` |

The same explicit `T` dtype parameter is required for `VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, and `MatrixField<T>` kernel parameters. These compound parameters are still one-dimensional native ndarray arguments at the descriptor/ABI level. `Tensor`, `Field`, and compound storage annotations without a dtype parameter are rejected; do not rely on an implicit `I32` default.

```haxe
var k = Kernel.build(ctx, macro (a:Tensor<F32>, out:Tensor<F32>) -> {
  for (i in 0...4) {
    out[i] = (a[i] : quadrants.Types.F32);
  }
});
```

## Inline kernel helper functions

Static methods marked `@:qdFunc` can be called from kernels. Single-return-expression helpers can appear inside expressions. Statement-bodied helpers with locals, `if`, `for`, and final `return` are inlined when the call is the direct initializer, assignment RHS, or returned value; recursion is rejected.

Helpers declared on the local class are collected automatically:

```haxe
@:qdFunc
static function square(x:Int):Int {
  return x * x;
}

var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>, n:Int) -> {
  for (i in 0...n) {
    out[i] = square(a[i]);
  }
});
```

Reusable helper libraries are explicit. Pass classes containing `@:qdFunc` static methods through the `helpers` option; no global classpath scan is performed.

```haxe
class MyKernelHelpers {
  @:qdFunc
  public static function squarePlusOne(x:Int):Int {
    return x * x + 1;
  }
}

var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>, n:Int) -> {
  for (i in 0...n) {
    out[i] = MyKernelHelpers.squarePlusOne(a[i]);
  }
}, {helpers: [MyKernelHelpers]});
```

Helper names are resolved by method name inside the kernel DSL. Names must be unique across all helper classes listed in one build and across the local class; duplicate names fail compilation instead of using precedence. Helper functions may call other listed helper functions, but direct or mutual recursion fails compilation with the recursive call's source position.

Helper functions that need to access `Shared.array*` or `Shared.tile16*` storage should use `kernelRead(index)` and `kernelWrite(index, value)` inside the helper body. These methods exist so helper classes type-check as ordinary Haxe while the kernel builder lowers them back to device array loads/stores.

```haxe
@:qdFunc
public static function tilePrefix(value:Int):Int {
  var scratch = Shared.tile16I32();
  var lane = Block.threadIdx();
  scratch.kernelWrite(lane, value);
  Block.sync();
  return scratch.kernelRead(0);
}
```

The built-in `quadrants.simt` helper package follows this pattern for block reductions/scans, subgroup wrappers, and tile sorting helpers.

## Unsupported constructs

Unsupported syntax fails during Haxe compilation with an `Unsupported Quadrants HashLink ...` diagnostic. Current compile-fail coverage lives in `tests/hashlink/compile_fail/`.

Common unsupported constructs include:

- General Haxe arrays, classes, strings, and dynamic objects inside kernel bodies. `return [a, b, ...]`, `Vector.ofArray([...])`, `Struct.ofN(...)`, and struct-style object literals are the supported structured-value constructs; arbitrary objects remain unsupported.
- Function calls other than the supported math, atomic, `shape`, `bitCast`, `CompilerHints.assumeInRange`, loop-hint / `LoopConfig`, SIMT, packed-helper, first-class compound storage read/write, `Grid.threadIdx`, `Mesh.for*`, `Shared.array(...)`, `Shared.tile16(...)`, tensor `kernelRead`/`kernelWrite` inside helper bodies, and local or explicitly listed `@:qdFunc` helper calls. `StreamParallel.block(...)` is a reserved kernel-only marker, but this backend rejects it until native multi-stream lowering exists.
- `switch`, `try`/`catch`, `throw`, `do while`, and `for` over arbitrary iterables.
- Assigning to anything except a local variable, ndarray element, vector/matrix component, or struct field.
- Re-declaring a local variable in the same scope or shadowing a kernel parameter.
- Using a parameter as both a scalar and an ndarray.
- Indirect ndarray bases such as `foo(a)[i]`; index the kernel parameter directly.

If the Haxe macro accepts a kernel, native launch-time checks still validate argument count, dtype, rank, and context ownership before dispatch.
