import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestLoops {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [5]);
        out.fill(-1);
        k = Kernel.build(ctx, macro (out) -> {
          var i = 0;
          while (i < 5) {
            if (i == 1) {
              i = i + 1;
              continue;
            }
            if (i == 4) {
              break;
            }
            out[i] = i + 100;
            i = i + 1;
          }
        });
        k.launch(out);
        ctx.sync();
        expectEq("loop0", out.read(0), 100);
        expectEq("loop1", out.read(1), -1);
        expectEq("loop3", out.read(3), 103);
        expectEq("loop4", out.read(4), -1);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
