import quadrants.Context;
import quadrants.Kernel;
import quadrants.Grid;
import quadrants.Grouped;
import quadrants.Ndrange;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestNdrange {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [6]);
        k = Kernel.build(ctx, macro (b:Tensor<I32>, rows:I32, cols:I32) -> {
          for (i in 0...b.shape(0)) {
            b[i] = -1;
          }
          for (I in Ndrange.of(rows, cols)) {
            b[I[0] * cols + I[1]] = I[0] * 10 + I[1] + (Grid.threadIdx() >= 0 ? 0 : Grid.threadIdx());
          }
          for (I in Ndrange.ranges(1, rows, 1, cols)) {
            b[I[0] * cols + I[1]] += 100;
          }
          for (J in Grouped.of(cols)) {
            b[J[0]] += 10;
          }
        });
        k.launch(out, 2, 3);
        ctx.sync();
        expectEq("ndrange0", out.read(0), 10);
        expectEq("ndrange4", out.read(4), 111);
        expectEq("ndrange5", out.read(5), 112);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
