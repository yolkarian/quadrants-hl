import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestBasics {
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
      k = Kernel.build(ctx, macro (out) -> {
        var acc = 1;
        acc = acc + 2;
        out[0] = acc;
      });
      k.launch(out);
      ctx.sync();
      expectEq("local_assign", out.read(0), 3);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
