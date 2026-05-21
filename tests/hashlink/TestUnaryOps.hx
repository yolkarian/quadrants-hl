import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestUnaryOps {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = new Tensor<I32>(ctx, [4]);
      k = Kernel.build(ctx, macro (out, x) -> {
        out[0] = -x;
        out[1] = ~x;
        out[2] = abs(-x);
        out[3] = min(max(x, 3), 9);
      });
      k.launch(out, 5);
      ctx.sync();
      expectEq("neg", out.read(0), -5);
      expectEq("bit_not", out.read(1), ~5);
      expectEq("abs", out.read(2), 5);
      expectEq("minmax", out.read(3), 5);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
