import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;

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
      var a = new Tensor<I32>(ctx, [3]);
      var out = new Tensor<I32>(ctx, [3]);
      for (i in 0...3) a.write(i, i + 1);
      k = buildScale(ctx);
      k.launch(a, out, 3, 4);
      ctx.sync();
      expectEq("function0", out.read(0), 4);
      expectEq("function2", out.read(2), 12);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
