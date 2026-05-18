import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class VectorAdd {
  static function main():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      final n = 16;
      var a = ctx.ndarrayI32([n]);
      var b = ctx.ndarrayI32([n]);
      var out = ctx.ndarrayI32([n]);

      for (i in 0...n) {
        a.writeI32(i, i * 2);
        b.writeI32(i, 100 - i);
        out.writeI32(i, 0);
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
        var got = out.readI32(i);
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
