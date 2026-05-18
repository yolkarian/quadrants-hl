import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestIf {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([4]);
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
      expectEq("if_true", out.readI32(0), 1);
      expectEq("select", out.readI32(1), 30);
      k.launch(out, -2);
      ctx.sync();
      expectEq("if_false", out.readI32(0), -1);
      expectEq("select_false", out.readI32(1), 40);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
