import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestCompare {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = new Tensor<I32>(ctx, [6]);
      k = Kernel.build(ctx, macro (out, x, y) -> {
        if (x == y) out[0] = 1; else out[0] = 0;
        if (x != y) out[1] = 1; else out[1] = 0;
        if (x < y && y > 0) out[2] = 1; else out[2] = 0;
        out[3] = (x & 3) | (y ^ 1);
        if (!(x == y) || x >= y) out[4] = 1; else out[4] = 0;
        if (x <= y) out[5] = 1; else out[5] = 0;
      });
      k.launch(out, 2, 5);
      ctx.sync();
      expectEq("eq", out.read(0), 0);
      expectEq("neq", out.read(1), 1);
      expectEq("logic", out.read(2), 1);
      expectEq("bit", out.read(3), (2 & 3) | (5 ^ 1));
      expectEq("not_or_gte", out.read(4), 1);
      expectEq("lte", out.read(5), 1);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
