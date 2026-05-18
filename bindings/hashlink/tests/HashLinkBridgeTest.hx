import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

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
      var a = ctx.ndarrayI32([N]);
      var b = ctx.ndarrayI32([N]);
      var out = ctx.ndarrayI32([N]);

      for (i in 0...N) {
        a.writeI32(i, i * 2);
        b.writeI32(i, 100 - i);
        out.writeI32(i, -1);
      }

      k = Kernel.build(ctx, macro (a, b, out, n) -> {
        for (i in 0...n) {
          out[i] = a[i] + b[i];
        }
      });
      k.launch(a, b, out, N);
      ctx.sync();

      for (i in 0...N) {
        expectEq('vector_add[${i}]', out.readI32(i), i * 2 + (100 - i));
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
