import quadrants.Context;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Types.F32;

class TestNativeFunctions {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectFloat(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    try {
      var i32 = new Tensor<I32>(ctx, [2, 2]);
      i32.fill(4);
      i32.writeAt([1, 1], 9);
      expectEq("fill_i32", i32.read(0), 4);
      expectEq("read_i32_multi", i32.readAt([1, 1]), 9);

      var f32 = new Tensor<F32>(ctx, [1]);
      f32.fill(1.25);
      expectFloat("fill_f32", f32.read(0), 1.25);
      ctx.sync();
      ctx.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
  }
}
