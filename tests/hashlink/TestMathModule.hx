import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F64;

class TestMathModule {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectFloat(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([4]);
      k = Kernel.build(ctx, macro (out, x) -> {
        out[0] = abs(-x);
        out[1] = min(x, 7);
        out[2] = max(x, 7);
        out[3] = cast(Math.floor(3.9), Int);
      });
      k.launch(out, 5);
      ctx.sync();
      expectEq("abs", out.readI32(0), 5);
      expectEq("min", out.readI32(1), 5);
      expectEq("max", out.readI32(2), 7);
      expectEq("floor", out.readI32(3), 3);
      k.close();

      var fout:Tensor<F64> = ctx.ndarrayF64([4]);
      k = Kernel.build(ctx, macro (fout:Tensor<F64>) -> {
        fout[0] = Math.sqrt(9.0);
        fout[1] = Math.ceil(2.1);
        fout[2] = Math.sin(0.0);
        fout[3] = Math.cos(0.0);
      });
      k.launch(fout);
      ctx.sync();
      expectFloat("sqrt", fout.readF64(0), 3.0);
      expectFloat("ceil", fout.readF64(1), 3.0);
      expectFloat("sin", fout.readF64(2), 0.0);
      expectFloat("cos", fout.readF64(3), 1.0);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
