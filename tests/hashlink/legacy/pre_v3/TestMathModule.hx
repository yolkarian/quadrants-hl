import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Types.F64;

class TestMathModule {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectFloat(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [4]);
        k = Kernel.build(ctx, macro (out, x) -> {
          out[0] = abs(-x);
          out[1] = min(x, 7);
          out[2] = max(x, 7);
          out[3] = cast(Math.floor(3.9), Int);
        });
        k.launch(out, 5);
        ctx.sync();
        expectEq("abs", out.read(0), 5);
        expectEq("min", out.read(1), 5);
        expectEq("max", out.read(2), 7);
        expectEq("floor", out.read(3), 3);
        k.close();
        k = null;

        var fout:Tensor<F64> = new Tensor<F64>(ctx, [5]);
        k = Kernel.build(ctx, macro (fout:Tensor<F64>) -> {
          fout[0] = Math.sqrt(9.0);
          fout[1] = Math.ceil(2.1);
          fout[2] = Math.sin(0.0);
          fout[3] = Math.cos(0.0);
          fout[4] = Math.atan(1.0);
        });
        k.launch(fout);
        ctx.sync();
        expectFloat("sqrt", fout.read(0), 3.0);
        expectFloat("ceil", fout.read(1), 3.0);
        expectFloat("sin", fout.read(2), 0.0);
        expectFloat("cos", fout.read(3), 1.0);
        expectFloat("atan", fout.read(4), 0.785398);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
