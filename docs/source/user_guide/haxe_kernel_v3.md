# Haxe kernels

Haxe kernels are macro arrow functions lowered to Quadrants IR. They are intentionally not arbitrary Haxe: unsupported host APIs, dynamic objects, arbitrary iterators, and unsupported calls fail at Haxe compile time.

Use typed `Kernel.build`:

```haxe
final add = Kernel.build(ctx, macro (a:Tensor<F32>, b:Tensor<F32>, out:Tensor<F32>, n:I32) -> {
  for (i in 0...n) out[i] = a[i] + b[i];
});

add.launch(a, b, out, n);
```

Every parameter must have an explicit type. Supported public parameter families are primitive scalars, `Spec<T>` specialization constants, `Tensor<T>`, `Field<T>`, `StructTensor<S>`, `StructField<S>`, mesh relations/attributes, and quantized tensor wrappers. A parameter must be used consistently as one resource kind and rank; launch-time validation checks dtype, rank, argument count, and context ownership.

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

Mesh loops over static domains use `Mesh.forVertices(count)`, `Mesh.forEdges(count)`, `Mesh.forFaces(count)`, or `Mesh.forCells(count)`. Counts are integer literals or `Static.value(...)` literals, so the mesh domain is part of the lowered descriptor rather than a hidden host object capture.

```haxe
final k = Kernel.build(ctx, macro (relation:MeshRelation<Edge, Vertex>, mass:MeshAttribute<Vertex, I32>, edgeSum:Tensor<I32>) -> {
  for (e in Mesh.forEdges(2)) {
    var sum = 0;
    for (j in 0...relation.size(e)) {
      sum += mass.read(relation.get(e, j));
    }
    edgeSum[e] = sum;
  }
});
```

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

Stream and graph objects are host-side control objects. Do not call `ctx.createStream()`, `Graph.autoStream()`, event methods, or other stream APIs inside a kernel body; those calls are rejected by the kernel macro. Inside `Graph.parallel` blocks, `Graph.autoStream()` is a host helper used to choose the launch stream for `kernel.launchOn(...)`.

## Helper discovery

Local static `@:qdFunc` methods are collected automatically. Reusable helper libraries must be passed explicitly with the `helpers` option; the macro does not scan the classpath.

```haxe
class Helpers {
  @:qdFunc public static function square(x:Int):Int return x * x;
}

final k = Kernel.build(ctx, macro (x:Tensor<I32>, out:Tensor<I32>, n:Int) -> {
  for (i in 0...n) out[i] = Helpers.square(x[i]);
}, {helpers: [Helpers]});
```

Helper names must be unique across all listed helper classes. Direct or mutual recursion is rejected.
