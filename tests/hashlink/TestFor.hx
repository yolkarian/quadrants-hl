import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestFor {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var out = ctx.ndarrayI32([6]);
      out.fillI32(0);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[i] = i * 2;
        }
      });
      k.launch(out, 6);
      ctx.sync();
      for (i in 0...6) expectEq('for[${i}]', out.readI32(i), i * 2);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
