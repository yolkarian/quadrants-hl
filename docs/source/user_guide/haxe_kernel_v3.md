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

AD uses explicit typed launches. Generated `QKernelN` wrappers expose `launchTape(tape, ...)`, `grad()`, `forwardGrad()`, and `validationKernel()`. Only real floating tensor/field dtypes (`F16`/`F32`/`F64`) can allocate `grad`/`dual` storage; integer and boolean resources raise an explicit no-grad error.

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

`CustomGradient.register` installs the replacement for subsequent typed `forward.launchTape(tape, ...)` calls with the same forward kernel descriptor. `launchTapeOn(stream, tape, ...)` is intentionally unsupported and raises an explicit error; keep Tape recording on the default stream and use `launchOn` outside Tape scopes. Reverse/validation AD currently rejects dynamic `while` loops on unsupported backends rather than falling through to a native failure.

Kernel-local linalg can use scalar component helpers or the aggregate facade:

```haxe
final k = Kernel.build(ctx, macro (out:Tensor<F32>) -> {
  var a:Matrix<Float> = Matrix.ofArray(2, 2, [2.0, 0.0, 0.0, 4.0]);
  var b:Vector<Float> = Vector.ofArray([6.0, 8.0]);
  var x = LinalgDevice.solve2(a, b);
  var r = LinalgDevice.polar2Rotation(a);
  out[0] = x[0];
  out[1] = r.kernelGet(0, 0);
}, {helpers: [DeviceLinalg, LinalgDevice]});
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
k.launchGraphWhile(controlI32Tensor, args...); // host-controlled typed loop
k.launchGraphDoWhile(controlI32Tensor, args...); // control tensor must also be one of args
```

`Graph.parallel(ctx, blocks)` accepts a single block everywhere. Multiple blocks require `ctx.capabilities().streamParallel`; unsupported backends throw instead of pretending to run in parallel. Use `Graph.sequence(ctx, blocks)` when explicit sequential composition is intended.
