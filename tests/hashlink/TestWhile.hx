import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestWhile {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([8]);
      out.fillI32(-1);
      k = Kernel.build(ctx, macro (out, n) -> {
        var i = 0;
        while (i < n) {
          if (i == 3) {
            i = i + 1;
            continue;
          }
          if (i == 6) {
            break;
          }
          out[i] = i * 10;
          i = i + 1;
        }
      });
      k.launch(out, 8);
      ctx.sync();
      expectEq("while0", out.readI32(0), 0);
      expectEq("while3", out.readI32(3), -1);
      expectEq("while5", out.readI32(5), 50);
      expectEq("while6", out.readI32(6), -1);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
