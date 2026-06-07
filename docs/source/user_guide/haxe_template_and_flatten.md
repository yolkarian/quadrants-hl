# Haxe flatten and data-oriented helpers

## `@:qdFlatten`

Annotate a host container class with `@:qdFlatten` so `QD.kernel(...)` can flatten its members into typed kernel arguments.

```haxe
@:qdFlatten
class State {
  public final x:Tensor<I32>;
  @:param public final bias:I32;
  @:template public final n:I32;

  public function new(x, bias, n) {
    this.x = x;
    this.bias = bias;
    this.n = n;
  }
}

var step = QD.kernel(ctx, macro (state:State) -> {
  for (i in 0...state.n) {
    state.x[i] = state.x[i] + state.bias;
  }
});
```

Rules:

- resource members such as `Tensor<T>`, `Field<T>`, `BufferView<T>`, `VectorNdarray<T>`, `MatrixNdarray<T>`, `VectorField<T>`, and `MatrixField<T>` are flattened automatically;
- primitive members must be marked `@:template` or `@:param`;
- `@:qdIgnore` excludes a field from flattening;
- nested `@:qdFlatten` objects are supported recursively;
- `Dynamic` members are rejected.

`quadrants.flatten.Flattened.specKey(value)` exposes the template/resource digest used for migration tooling and cache-key style inspection.

## Data-oriented classes

Haxe cannot trigger build macros from metadata alone, so the current data-oriented path is:

- annotate the class with `@:qdDataOriented("ctx")` (or omit the string to use the default `ctx` field name);
- extend `quadrants.flatten.DataOriented`;
- mark instance kernel methods with `@:kernel`.

```haxe
@:qdDataOriented("ctx")
class ParticleSim extends quadrants.flatten.DataOriented {
  public final ctx:Context;
  public final x:Tensor<I32>;
  @:template public final n:I32;

  public function new(ctx, x, n) {
    this.ctx = ctx;
    this.x = x;
    this.n = n;
  }

  @:kernel
  public function add(delta:I32):Void {
    for (i in 0...n) {
      x[i] = x[i] + delta;
    }
  }
}
```

The build macro generates a cached `QKernelN` wrapper and forwards each method call through `QD.kernel(...)` with `this` flattened as the first parameter.
