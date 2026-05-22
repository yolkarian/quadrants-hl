import quadrants.Context;
import quadrants.Kernel;
import quadrants.Static;
import quadrants.Mesh;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestFor {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [6]);
        out.fill(0);
        k = Kernel.build(ctx, macro (out, n) -> {
          for (i in 0...n) {
            out[i] = i * 2;
          }
          for (j in Static.range(0, Static.value(2))) {
            out[j] += Static.value(1);
          }
          if (Static.value(true)) {
            out[2] = 99;
          }
          if (Static.value(false)) {
            out[3] = 99;
          }
        });
        k.launch(out, 6);
        ctx.sync();
        for (i in 0...6) expectEq('for[${i}]', out.read(i), i == 2 ? 99 : (i < 2 ? i * 2 + 1 : i * 2));
        k.close();
        k = Kernel.build(ctx, macro (out) -> {
          for (v in Mesh.forVertices(6)) {
            out[v] = v + 3;
          }
        });
        out.fill(0);
        k.launch(out);
        ctx.sync();
        for (i in 0...6) expectEq('mesh_for[${i}]', out.read(i), i + 3);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
