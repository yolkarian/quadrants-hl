import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestAtomic {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([1]);
      out.fillI32(0);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[0] += 1;
        }
      });
      k.launch(out, 32);
      ctx.sync();
      expectEq("atomic_add", out.readI32(0), 32);
      k.close();

      out.fillI32(40);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[0] -= 1;
        }
      });
      k.launch(out, 8);
      ctx.sync();
      expectEq("atomic_sub", out.readI32(0), 32);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
