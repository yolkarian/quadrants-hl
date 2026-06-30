# Haxe kernels v3

Use typed `Kernel.build`:

```haxe
final add = Kernel.build(ctx, macro (a:Tensor<F32>, b:Tensor<F32>, out:Tensor<F32>, n:I32) -> {
  for (i in 0...n) out[i] = a[i] + b[i];
});

add.launch(a, b, out, n);
```

`Spec<T>` marks a specialization constant in the descriptor/cache key model. The generated launcher sends `Spec<T>` values through the specialization channel, not as kernel runtime arguments; native code specializes/caches the compiled kernel by those values.

```haxe
final k = Kernel.build(ctx, macro (x:Tensor<F32>, n:Spec<Int>) -> {
  for (i in 0...n) x[i] += 1.0;
});
k.launch(x, Spec.of(128));
```

For host-side containers use `@:build(quadrants.macro.QdArgs.build())`. Resource members are runtime args; primitive/enum members are specialization constants by default. `@:kernel` instance methods are lowered to typed kernels that launch with `this` as the first flattened argument.

```haxe
@:build(quadrants.macro.QdArgs.build())
class Sim {
  public var x:Field<F32>;
  public var n:Int;

  @:kernel public function clear():Void {
    for (i in 0...n) x[i] = 0.0;
  }
}
```

AD uses explicit typed launches. Generated `QKernelN` wrappers expose `launchTape(tape, ...)`, `grad()`, `forwardGrad()`, and `validationKernel()`:

```haxe
Tape.withLoss(ctx, loss, tape -> {
  forward.launchTape(tape, x, y, n);
  reduce.launchTape(tape, y, loss, n);
});

final custom = CustomGradient.register(forward, {
  backward: backward,
  forwardGrad: forwardGrad,
  validation: validation
});
```

Struct, mesh, and quant resource parameters are typed. Scalar-member `StructTensor<S>` values can be load-copy-stored, mesh relation/attribute params expose `size/get/read/write`, and `QuantizedF32Tensor` exposes kernel `read/write` with explicit quantization metadata.

Streams and graph control are explicit and typed:

```haxe
final s = ctx.createStream();
k.launchOn(s, args...);

final e = ctx.createEvent();
e.record(s);
other.wait(e);

k.launchGraph(args...);
k.launchGraphWhile(controlI32Tensor, args...);
k.launchGraphDoWhile(controlI32Tensor, args...);
```
