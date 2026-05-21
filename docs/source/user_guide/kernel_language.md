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

Kernel parameters may be primitive scalars, `Tensor<T>`/`Field<T>` ndarrays, or one-dimensional `BufferView<T>` views. If an untyped parameter is used as `a[i]`, it is inferred as an ndarray; otherwise it is inferred as a scalar. Explicit annotations can be used when you want a non-default dtype.

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

## Supported statements

- Blocks.
- Local variable declarations and assignments with block, loop, and branch scope.
- `for (i in start...end)` range loops.
- `for (I in Ndrange.of(a, b, ...))` one- to four-dimensional nested range loops from zero, or `Ndrange.ranges(begin0, end0, ...)` for explicit begin/end pairs; use `I[0]`, `I[1]`, ... inside the body.
- `for (i in fieldOrTensor)` or `for (i in Grouped.of(fieldOrTensor))` struct-for over a direct `Field<T>` or `Tensor<T>` parameter.
- `for (i in Static.range(begin, end))` static loops over integer literals; `Static.value(literal)` can wrap compile-time literal constants used in static bounds or expressions.
- `for (v in Mesh.forVertices(count))`, `Mesh.forEdges(count)`, `Mesh.forFaces(count)`, or `Mesh.forCells(count)` static mesh-for over a non-negative integer literal count. Current mesh-for support covers loop indices and no relation access.
- `while` loops.
- `break` and `continue` inside loops.
- `if` / `else` statements. Literal `if (true)` / `if (false)` and `if (Static.value(trueOrFalse))` conditions are expanded at macro time.
- Ndarray element assignment, vector/matrix component assignment, and struct-field assignment for kernel locals.
- Atomic compound assignment (`+=`, `-=`, `*=`, `&=`, `|=`, `^=`) on ndarray elements. Use `atomicAdd(a[i], value)` and related atomic calls when the old value is needed.
- Loop scheduling hints before the loop they decorate: `blockDim(n)`, `parallelize(n)`, and `serialize()`.
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
- Math calls: `abs`, `sin`, `asin`, `cos`, `acos`, `tan`, `atan`, `tanh`, `exp`, `log`, `sqrt`, `rsqrt`, `floor`, `ceil`, `round`, `min`, `max`, `atan2`, `pow`, `inv`, `rcp`, `popcnt`, `clz`, `ffs`, `sgn`, `isnan`, `isinf`, and `select(cond, a, b)`.
- Random scalar calls: `randI32()`, `randU32()`, `randF32()`, and `randF64()`.
- Atomic fetch operations: `atomicAdd`, `atomicSub`, `atomicMul`, `atomicMin`, `atomicMax`, `atomicAnd`, `atomicOr`, `atomicXor`, `atomicExchange`, and `atomicCompareExchange(target, expected, desired)` on ndarray elements return the previous value.
- `shape(tensor, axis)` or `tensor.shape(axis)` returns a tensor/field parameter's runtime extent along a literal axis.
- Vector locals from `Vec2`/`Vec3`/`Vec4` factories or `Vector.ofArray([...])`, with component/index access, elementwise arithmetic, `dot`, `cross`, `norm`, and `normalized` lowering to scalar IR.
- Matrix locals from `Mat2`/`Mat3`/`Mat4` factories or `Matrix.ofArray(rows, cols, [...])`, with constant row/column indexing, elementwise arithmetic, `matmul`, and `transpose` lowering to scalar IR.
- Shared local arrays from `Shared.arrayI8/I16/I32/I64/U8/U16/U32/U64/U1/F16/F32/F64(size)` or fixed 16x16 tiles from matching `Shared.tile16*()` factories with normal `shared[i]` indexing inside kernels.
- Struct locals from `Struct.ofN("field", value, ...)` with scalar fields, field reads, and field assignment/compound assignment.
- `Grid.threadIdx()` returns the backend linear thread index for the current lowered loop.
- SIMT helpers: `Block.threadIdx()`, `Block.barrierAnd(value)`, `Block.barrierOr(value)`, `Block.barrierCount(value)`, `Subgroup.size()`, `Subgroup.invocationId()`, `Subgroup.elect()`, `Subgroup.shuffle(value, lane)`, `Subgroup.shuffleUp(value, delta)`, `Subgroup.shuffleDown(value, delta)`, `Subgroup.broadcast(value, lane)`, `Workgroup.localInvocationId()`, `Workgroup.globalInvocationId()`, `Grid.activeMask()`, and `Grid.vkGlobalThreadIdx()`.

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

```haxe
var k = Kernel.build(ctx, macro (a, out) -> {
  for (i in 0...4) {
    out[i] = (a[i] : quadrants.Types.F32);
  }
});
```

## Inline kernel helper functions

Static methods marked `@:qdFunc` can be called from kernels. Single-return-expression helpers can appear inside expressions. Statement-bodied helpers with locals, `if`, `for`, and final `return` are inlined when the call is the direct initializer, assignment RHS, or returned value; recursion is rejected.

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

## Unsupported constructs

Unsupported syntax fails during Haxe compilation with an `Unsupported Quadrants HashLink ...` diagnostic. Current compile-fail coverage lives in `tests/hashlink/compile_fail/`.

Common unsupported constructs include:

- General Haxe arrays, object literals, classes, strings, and dynamic objects inside kernel bodies. `return [a, b, ...]`, `Vector.ofArray([...])`, and `Struct.ofN(...)` are kernel-only macro constructs.
- Function calls other than the supported math, atomic, `shape`, `bitCast`, loop-hint, SIMT, `Grid.threadIdx`, `Mesh.for*`, and `@:qdFunc` calls.
- `switch`, `try`/`catch`, `throw`, `do while`, and `for` over arbitrary iterables.
- Assigning to anything except a local variable, ndarray element, vector/matrix component, or struct field.
- Re-declaring a local variable in the same scope or shadowing a kernel parameter.
- Using a parameter as both a scalar and an ndarray.
- Indirect ndarray bases such as `foo(a)[i]`; index the kernel parameter directly.

If the Haxe macro accepts a kernel, native launch-time checks still validate argument count, dtype, rank, and context ownership before dispatch.
