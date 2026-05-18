import quadrants.Context;
import quadrants.Types.Arch;

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
      var i32 = ctx.ndarrayI32([2, 2]);
      i32.fillI32(4);
      i32.writeI32At([1, 1], 9);
      expectEq("fill_i32", i32.readI32(0), 4);
      expectEq("read_i32_multi", i32.readI32(1, 1), 9);

      var f32 = ctx.ndarrayF32([1]);
      f32.fillF32(1.25);
      expectFloat("fill_f32", f32.readF32(0), 1.25);
      ctx.sync();
      ctx.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
  }
}
