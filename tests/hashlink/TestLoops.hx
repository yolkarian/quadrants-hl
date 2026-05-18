import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestLoops {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([5]);
      out.fillI32(-1);
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
      expectEq("loop0", out.readI32(0), 100);
      expectEq("loop1", out.readI32(1), -1);
      expectEq("loop3", out.readI32(3), 103);
      expectEq("loop4", out.readI32(4), -1);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
