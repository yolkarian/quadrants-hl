import quadrants.Context;
import quadrants.Kernel;
import quadrants.Matrix;
import quadrants.Vector;
import quadrants.Types.Arch;

class TestMatrix {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cuda);
    var k:Kernel = null;
    try {
      var a = ctx.ndarrayI32([2, 3]);
      var out = ctx.ndarrayI32([2]);
      for (i in 0...6) a.writeI32(i, i + 10);
      k = Kernel.build(ctx, macro (a, out) -> {
        for (i in 0...2) {
          out[i] = a[i][1];
        }
      });
      k.launch(a, out);
      ctx.sync();
      expectEq("matrix0", out.readI32(0), 11);
      expectEq("matrix1", out.readI32(1), 14);
      expectEq("host_multi", a.readI32(1, 2), 15);

      var v = Vector.ofArray([1, 2, 3]);
      var w = Vector.ofArray([4, 5, 6]);
      var sum = v + w;
      expectEq("vector_access", sum[1], 7);

      var m = new Matrix<Int>(2, 2, [1, 2, 3, 4]);
      var n = Matrix.filled(2, 2, 10);
      var ms = m.add(n);
      expectEq("matrix_access", ms.get(1, 0), 13);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
