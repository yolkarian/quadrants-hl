import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;

class TestTypes {
  static function expectEq(name:String, got:Dynamic, expected:Dynamic):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var i8 = ctx.ndarrayI8([2]);
      i8.writeI8(0, -7);
      expectEq("i8", i8.readI8(0), -7);

      var i16 = ctx.ndarrayI16([2]);
      i16.fillI16(1234);
      expectEq("i16", i16.readI16(1), 1234);

      var i32 = ctx.ndarrayI32([2]);
      i32.writeI32(0, 42);
      expectEq("i32", i32.readI32(0), 42);

      var u8 = ctx.ndarrayU8([2]);
      u8.writeU8(0, 250);
      expectEq("u8", u8.readU8(0), 250);

      var f32 = ctx.ndarrayF32([2]);
      f32.writeF32(0, 1.5);
      expectEq("f32", f32.readF32(0), 1.5);

      var f64 = ctx.ndarrayF64([2]);
      f64.fillF64(2.25);
      expectEq("f64", f64.readF64(1), 2.25);

      var ka:Tensor<F32> = ctx.ndarrayF32([2]);
      var kout:Tensor<F32> = ctx.ndarrayF32([2]);
      ka.writeF32(0, 1.5);
      ka.writeF32(1, 2.5);
      k = Kernel.build(ctx, macro (ka:Tensor<F32>, kout:Tensor<F32>, n:Int) -> {
        for (i in 0...n) {
          kout[i] = ka[i] + 1;
        }
      });
      k.launch(ka, kout, 2);
      ctx.sync();
      expectEq("kernel_f32", kout.readF32(0), 2.5);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
