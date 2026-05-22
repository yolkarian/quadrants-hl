import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestPrintRuntime {
  public static function run():Void {
    var ctx = new Context();
    var kernel:Kernel = null;
    try {
      var out = new Tensor<I32>(ctx, [1]);
      out.fill(0);
      kernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
        print("hashlink-print-token");
        out[0] = 1;
      });
      kernel.launch(out);
      ctx.sync();
      if (out.read(0) != 1) {
        throw "print runtime output mismatch";
      }
    } catch (e:Dynamic) {
      TestRuntimeSupport.closeKernel(kernel);
      TestRuntimeSupport.closeContext(ctx);
      throw e;
    }
    TestRuntimeSupport.closeKernel(kernel);
    TestRuntimeSupport.closeContext(ctx);
  }
}
