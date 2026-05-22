import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestGraphRuntime {
  static inline final N = 4;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectFilled(name:String, tensor:Tensor<I32>, expected:Int):Void {
    for (i in 0...N) {
      expectEq('${name}[${i}]', tensor.read(i), expected);
    }
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx:Context) {
      var kernels:Array<Kernel> = [];
      try {
        var defaultGraphOut = new Tensor<I32>(ctx, [N]);
        defaultGraphOut.fill(0);
        var defaultGraphKernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
          for (i in 0...out.shape(0)) {
            out[i] = out[i] + 1;
          }
          for (i in 0...out.shape(0)) {
            out[i] = out[i] + 2;
          }
        }, {graph: true});
        kernels.push(defaultGraphKernel);
        defaultGraphKernel.launch(defaultGraphOut);
        defaultGraphKernel.launch(defaultGraphOut);
        ctx.sync();
        expectFilled("graph_default_launch", defaultGraphOut, 6);

        var explicitGraphOut = new Tensor<I32>(ctx, [N]);
        explicitGraphOut.fill(0);
        var explicitGraphKernel = Kernel.build(ctx, macro (out:Tensor<I32>, delta:Int) -> {
          for (i in 0...out.shape(0)) {
            out[i] = out[i] + delta;
          }
          for (i in 0...out.shape(0)) {
            out[i] = out[i] + 1;
          }
        });
        kernels.push(explicitGraphKernel);
        explicitGraphKernel.launchGraph(explicitGraphOut, 3);
        explicitGraphKernel.launchGraph(explicitGraphOut, 5);
        ctx.sync();
        expectFilled("graph_explicit_launch", explicitGraphOut, 10);

        var loopOut = new Tensor<I32>(ctx, [N]);
        var counter = new Tensor<I32>(ctx, [1]);
        var loopKernel = Kernel.build(ctx, macro (out:Tensor<I32>, counter:Tensor<I32>) -> {
          for (i in 0...out.shape(0)) {
            out[i] = out[i] + 1;
          }
          counter[0] = counter[0] - 1;
        }, {graph: true});
        kernels.push(loopKernel);

        loopOut.fill(0);
        counter.write(0, 4);
        loopKernel.launchGraphDoWhile(1, loopOut, counter);
        ctx.sync();
        expectFilled("graph_do_while_first", loopOut, 4);
        expectEq("graph_do_while_counter_first", counter.read(0), 0);

        loopOut.fill(0);
        counter.write(0, 2);
        loopKernel.launchGraphDoWhile(1, loopOut, counter);
        ctx.sync();
        expectFilled("graph_do_while_second", loopOut, 2);
        expectEq("graph_do_while_counter_second", counter.read(0), 0);

        loopOut.fill(0);
        counter.write(0, 3);
        loopKernel.launchGraphWhile(1, loopOut, counter);
        expectFilled("graph_while_first", loopOut, 3);
        expectEq("graph_while_counter_first", counter.read(0), 0);

        loopOut.fill(5);
        counter.write(0, 0);
        loopKernel.launchGraphWhile(1, loopOut, counter);
        expectFilled("graph_while_skips_zero", loopOut, 5);
        expectEq("graph_while_counter_zero", counter.read(0), 0);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
    });
  }
}
