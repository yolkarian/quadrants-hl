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

Kernel parameters may be primitive scalars or `Tensor<T>` ndarrays. If a parameter is used as `a[i]`, it is inferred as an ndarray; otherwise it is inferred as a scalar. Explicit annotations can be used when you want a non-default dtype.

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

## Supported statements

- Blocks.
- Local variable declarations and assignments.
- `for (i in start...end)` range loops.
- `while` loops.
- `break` and `continue` inside loops.
- `if` / `else` statements.
- Ndarray element assignment.
- Atomic `+=` and `-=` on ndarray elements. Use `atomicAdd(a[i], value)` when the old value is needed.
- `return;` with no value.

## Supported expressions

- Integer and floating-point literals.
- Scalar parameter and local variable loads.
- Ndarray element loads.
- Arithmetic: `+`, `-`, `*`, `/`, `%`.
- Comparisons: `==`, `!=`, `<`, `<=`, `>`, `>=`.
- Boolean logic: `&&`, `||`, `!`.
- Integer bitwise ops: `&`, `|`, `^`, `<<`, `>>`, `>>>`, `~`.
- Unary negation: `-x`.
- Expression-level `if`: `if (cond) a else b`.
- Explicit casts/check types to supported primitive dtypes.
- Math calls: `abs`, `sin`, `cos`, `tan`, `exp`, `log`, `sqrt`, `floor`, `ceil`, `min`, `max`.
- Atomic fetch-add: `atomicAdd(a[i], value)` atomically adds to an ndarray element and returns the previous value.

## Dtypes in annotations and casts

The macro recognizes these type names in scalar annotations, `Tensor<T>` parameters, and casts:

| Haxe type | Quadrants dtype |
| --- | --- |
| `Int`, `quadrants.Types.I32` | `i32` |
| `haxe.Int64`, `quadrants.Types.I64` | `i64` |
| `UInt`, `quadrants.Types.U32` | `u32` |
| `quadrants.Types.I8`, `I16`, `U8`, `U16`, `U64` | matching integer dtype |
| `hl.F32`, `quadrants.Types.F32` | `f32` |
| `Float`, `quadrants.Types.F64` | `f64` |

```haxe
var k = Kernel.build(ctx, macro (a, out) -> {
  for (i in 0...4) {
    out[i] = (a[i] : quadrants.Types.F32);
  }
});
```

## Unsupported constructs

Unsupported syntax fails during Haxe compilation with an `Unsupported Quadrants HashLink ...` diagnostic. Current compile-fail coverage lives in `tests/hashlink/compile_fail/`.

Common unsupported constructs include:

- Haxe arrays, array literals, structures, classes, strings, and dynamic objects inside kernel bodies.
- Function calls other than the supported math calls.
- `switch`, `try`/`catch`, `throw`, `do while`, `for` over arbitrary iterables, and `return value`.
- Assigning to anything except a local variable or ndarray element.
- Re-declaring a local variable in a way that would require a distinct scope allocation.
- Using a parameter as both a scalar and an ndarray.
- Indirect ndarray bases such as `foo(a)[i]`; index the kernel parameter directly.

If the Haxe macro accepts a kernel, native launch-time checks still validate argument count, dtype, rank, and context ownership before dispatch.
