# Haxe typed kernels

API v3 promotes `Kernel.build(ctx, macro (...)->{...})` to the typed launch path. `QD.kernel(...)` remains as a compatibility alias layered on top of `KernelRaw`.

## Basic launch

```haxe
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.I32;

var add = QD.kernel(ctx, macro (a:Tensor<I32>, b:Tensor<I32>, out:Tensor<I32>, n:I32) -> {
  for (i in 0...n) {
    out[i] = a[i] + b[i];
  }
}, {name: "vec_add"});

add.launch(a, b, out, n);
```

All parameters must have explicit type annotations. This lets Haxe reject launch arity and dtype mismatches before runtime.

## Scalar and structured returns

For non-`Void` kernels, annotate the receiving `QKernelN` variable so `QD.kernel(...)` can recover the return type from the expected Haxe type:

```haxe
import quadrants.kernel.QKernel2;

typedef Pair = {
  var first:I32;
  var second:I32;
}

var sum:QKernel2<Tensor<I32>, I32, I32> = QD.kernel(ctx, macro (values:Tensor<I32>, n:I32) -> {
  var total:I32 = 0;
  for (i in 0...n) total += values[i];
  return total;
});

var pair:quadrants.kernel.QKernel1<I32, Pair> = QD.kernel(ctx, macro (value:I32) -> {
  return {first: value, second: value + 1};
});
```

Structured returns are decoded through the existing `Struct.decodeSchema(...)` machinery.

## Relationship to `Kernel` and `KernelRaw`

- `KernelRaw` is the explicit dynamic boundary: `launchDynamic`, `launchRetDynamic`, and `launchRetsDynamic`.
- `Kernel` remains the compatibility facade for existing call sites.
- `QD.kernel` is the recommended entrypoint for new typed code.
