import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class HashLinkBridgeTest {
  static inline final N = 16;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function testVectorAddCuda():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var a = new Tensor<I32>(ctx, [N]);
      var b = new Tensor<I32>(ctx, [N]);
      var out = new Tensor<I32>(ctx, [N]);

      for (i in 0...N) {
        a.write(i, i * 2);
        b.write(i, 100 - i);
        out.write(i, -1);
      }

      k = Kernel.build(ctx, macro (a, b, out, n) -> {
        for (i in 0...n) {
          out[i] = a[i] + b[i];
        }
      });
      k.launch(a, b, out, N);
      ctx.sync();

      for (i in 0...N) {
        expectEq('vector_add[${i}]', out.read(i), i * 2 + (100 - i));
      }
      if (k != null) {
        k.close();
      }
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) {
        k.close();
      }
      ctx.close();
      throw e;
    }
  }

  static function main():Void {
    testVectorAddCuda();
    Sys.println("hashlink cuda bridge tests ok");
  }
}
