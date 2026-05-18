import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestCast {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([1]);
      k = Kernel.build(ctx, macro (out, x) -> {
        out[0] = cast(x, Int);
      });
      k.launch(out, 17);
      ctx.sync();
      expectEq("cast", out.readI32(0), 17);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
