import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestFunction {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function buildScale(ctx:Context):Kernel {
    return Kernel.build(ctx, macro (a, out, n, scale) -> {
      for (i in 0...n) {
        out[i] = a[i] * scale;
      }
    });
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var a = ctx.ndarrayI32([3]);
      var out = ctx.ndarrayI32([3]);
      for (i in 0...3) a.writeI32(i, i + 1);
      k = buildScale(ctx);
      k.launch(a, out, 3, 4);
      ctx.sync();
      expectEq("function0", out.readI32(0), 4);
      expectEq("function2", out.readI32(2), 12);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
