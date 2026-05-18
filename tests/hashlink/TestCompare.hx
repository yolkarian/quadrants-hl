import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

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
      var out = ctx.ndarrayI32([6]);
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
      expectEq("eq", out.readI32(0), 0);
      expectEq("neq", out.readI32(1), 1);
      expectEq("logic", out.readI32(2), 1);
      expectEq("bit", out.readI32(3), (2 & 3) | (5 ^ 1));
      expectEq("not_or_gte", out.readI32(4), 1);
      expectEq("lte", out.readI32(5), 1);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
