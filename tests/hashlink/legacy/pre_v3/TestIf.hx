import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestIf {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [4]);
        k = Kernel.build(ctx, macro (out, x) -> {
          if (x > 0) {
            out[0] = 1;
          } else {
            out[0] = -1;
          }
          out[1] = if (x == 3) 30 else 40;
        });
        k.launch(out, 3);
        ctx.sync();
        expectEq("if_true", out.read(0), 1);
        expectEq("select", out.read(1), 30);
        k.launch(out, -2);
        ctx.sync();
        expectEq("if_false", out.read(0), -1);
        expectEq("select_false", out.read(1), 40);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
