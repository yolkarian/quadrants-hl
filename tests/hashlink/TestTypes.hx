import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I8;
import quadrants.Types.I16;
import quadrants.Types.I32;
import quadrants.Types.U8;
import quadrants.Types.F32;
import quadrants.Types.F64;

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
      var i8 = new Tensor<I8>(ctx, [2]);
      i8.write(0, -7);
      expectEq("i8", i8.read(0), -7);

      var i16 = new Tensor<I16>(ctx, [2]);
      i16.fill(1234);
      expectEq("i16", i16.read(1), 1234);

      var i32 = new Tensor<I32>(ctx, [2]);
      i32.write(0, 42);
      expectEq("i32", i32.read(0), 42);

      var u8 = new Tensor<U8>(ctx, [2]);
      u8.write(0, 250);
      expectEq("u8", u8.read(0), 250);

      var f32 = new Tensor<F32>(ctx, [2]);
      f32.write(0, 1.5);
      expectEq("f32", f32.read(0), 1.5);

      var f64 = new Tensor<F64>(ctx, [2]);
      f64.fill(2.25);
      expectEq("f64", f64.read(1), 2.25);

      var ka:Tensor<F32> = new Tensor<F32>(ctx, [2]);
      var kout:Tensor<F32> = new Tensor<F32>(ctx, [2]);
      ka.write(0, 1.5);
      ka.write(1, 2.5);
      k = Kernel.build(ctx, macro (ka:Tensor<F32>, kout:Tensor<F32>, n:Int) -> {
        for (i in 0...n) {
          kout[i] = ka[i] + 1;
        }
      });
      k.launch(ka, kout, 2);
      ctx.sync();
      expectEq("kernel_f32", kout.read(0), 2.5);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
