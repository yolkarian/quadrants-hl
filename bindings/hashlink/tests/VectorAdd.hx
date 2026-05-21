import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class VectorAdd {
  static function main():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      final n = 16;
      var a = new Tensor<I32>(ctx, [n]);
      var b = new Tensor<I32>(ctx, [n]);
      var out = new Tensor<I32>(ctx, [n]);

      for (i in 0...n) {
        a.write(i, i * 2);
        b.write(i, 100 - i);
        out.write(i, 0);
      }

      k = Kernel.build(ctx, macro (a, b, out, n) -> {
        for (i in 0...n) {
          out[i] = a[i] + b[i];
        }
      });
      k.launch(a, b, out, n);
      ctx.sync();

      for (i in 0...n) {
        var expected = i * 2 + (100 - i);
        var got = out.read(i);
        if (got != expected) {
          throw 'bad result at ${i}: ${got} != ${expected}';
        }
      }
      k.close();
      ctx.close();
      Sys.println("hashlink cuda vector add ok");
    } catch (e:Dynamic) {
      if (k != null) {
        k.close();
      }
      ctx.close();
      throw e;
    }
  }
}
