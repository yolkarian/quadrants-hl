import quadrants.Context;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.kernel.QKernel1;
import quadrants.kernel.QKernel2;

typedef TypedPair = {
  var first:I32;
  var second:I32;
}

class TestTypedKernelRuntime {
  static function expectEq(name:String, got:Dynamic, expected:Dynamic):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);

      var a = new Tensor<I32>(ctx, [4]);
      var b = new Tensor<I32>(ctx, [4]);
      var out = new Tensor<I32>(ctx, [4]);
      a.fromArray([1, 2, 3, 4]);
      b.fromArray([10, 20, 30, 40]);
      var add = QD.kernel(ctx, macro (a:Tensor<I32>, b:Tensor<I32>, out:Tensor<I32>, n:I32) -> {
        for (i in 0...n) {
          out[i] = a[i] + b[i];
        }
      }, {name: "typed_add"});
      add.launch(a, b, out, 4);
      expectEq("typed_kernel_launch_0", out.read(0), 11);
      expectEq("typed_kernel_launch_3", out.read(3), 44);
      expectEq("typed_kernel_name", add.name(), "typed_add");

      var sum:QKernel2<Tensor<I32>, I32, I32> = QD.kernel(ctx, macro (values:Tensor<I32>, n:I32) -> {
        var total:I32 = 0;
        for (i in 0...n) {
          total += values[i];
        }
        return total;
      });
      var total:I32 = sum.launch(out, 4);
      expectEq("typed_kernel_scalar_return", total, 110);

      var pairKernel:QKernel1<I32, TypedPair> = QD.kernel(ctx, macro (value:I32) -> {
        return {first: value, second: value + 1};
      });
      var pair:TypedPair = pairKernel.launch(7);
      expectEq("typed_kernel_object_return_first", pair.first, 7);
      expectEq("typed_kernel_object_return_second", pair.second, 8);

      var stream = ctx.stream();
      var streamKernel = QD.kernel(ctx, macro (out:Tensor<I32>) -> {
        out[0] = 99;
      });
      streamKernel.launchOn(stream, out);
      stream.sync();
      expectEq("typed_kernel_launch_on", out.read(0), 99);
      stream.close();

      var graphKernel = QD.kernel(ctx, macro (out:Tensor<I32>) -> {
        out[0] = out[0] + 1;
      });
      graphKernel.launchGraph(out);
      ctx.sync();
      expectEq("typed_kernel_launch_graph", out.read(0), 100);

      var gradForward = add.forwardGrad();
      expectEq("typed_kernel_forward_grad_name", gradForward.name(), add.name());

      ctx.close();
    } catch (e:Dynamic) {
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
