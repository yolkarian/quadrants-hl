import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestCast {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [1]);
        k = Kernel.build(ctx, macro (out, x) -> {
          out[0] = cast(x, Int);
        });
        k.launch(out, 17);
        ctx.sync();
        expectEq("cast", out.read(0), 17);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
