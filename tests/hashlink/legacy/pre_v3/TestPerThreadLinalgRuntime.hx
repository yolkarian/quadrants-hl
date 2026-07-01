import quadrants.Context;
import quadrants.Kernel;
import quadrants.Mat2;
import quadrants.Mat3;
import quadrants.Matrix;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Vector;
import quadrants.Vec2;

class TestPerThreadLinalgRuntime {
  static function expectClose(name:String, got:Float, expected:Float, epsilon:Float = 0.0001):Void {
    if (Math.abs(got - expected) > epsilon) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function expectThrows(name:String, body:Void->Void):Void {
    var thrown = false;
    try {
      body();
    } catch (_:Dynamic) {
      thrown = true;
    }
    if (!thrown) throw '${name}: expected exception';
  }

  static function testHostLinalg():Void {
    var one = Matrix.ofArray(1, 1, [5.0]);
    expectClose("det1", one.determinant(), 5.0);
    expectClose("inv1", one.inverse().get(0, 0), 0.2);

    var m = Matrix.ofArray(2, 2, [4.0, 7.0, 2.0, 6.0]);
    expectClose("det2", m.determinant(), 10.0);
    var inv = m.inverse();
    expectClose("inv2_00", inv.get(0, 0), 0.6);
    expectClose("inv2_01", inv.get(0, 1), -0.7);
    expectClose("inv2_10", inv.get(1, 0), -0.2);
    expectClose("inv2_11", inv.get(1, 1), 0.4);
    expectClose("trace2", m.trace(), 10.0);
    expectClose("frobenius2", m.frobeniusSquared(), 105.0);
    expectClose("matvec0", m.matvec(Vector.ofArray([1.0, 2.0]))[0], 18.0);
    expectClose("outer3", Matrix.outer(Vec2.f32(1.0, 2.0), Vec2.f32(3.0, 4.0)).get(1, 1), 8.0);
    expectClose("diag", Matrix.diag(Vector.ofArray([3.0, 4.0])).get(1, 1), 4.0);

    var det3 = Mat3.f32(6.0, 1.0, 1.0, 4.0, -2.0, 5.0, 2.0, 8.0, 7.0).determinant();
    expectClose("det3", det3, -306.0);
    expectThrows("singular_inverse", function() Matrix.ofArray(2, 2, [1.0, 2.0, 2.0, 4.0]).inverse());
  }

  static function testKernelLinalg(ctx:Context):Void {
    var out = new Tensor<F32>(ctx, [12]);
    var kernel:Kernel = null;
    try {
      out.fill(0.0);
      kernel = Kernel.build(ctx, macro (out:Tensor<F32>) -> {
        var m = Mat2.f32(4.0, 7.0, 2.0, 6.0);
        var det:F32 = m.determinant();
        var inv = m.inverse();
        var d = m.diagonal();
        var x = Vec2.f32(1.0, 2.0);
        var y = m.matvec(x);
        var outer = Matrix.outer(x, x);
        var diag = Matrix.diag(x);
        out[0] = det;
        out[1] = inv[0];
        out[2] = inv[1];
        out[3] = inv[2];
        out[4] = inv[3];
        out[5] = m.trace();
        out[6] = m.frobeniusSquared();
        out[7] = d[1];
        out[8] = y[0];
        out[9] = y[1];
        out[10] = outer[3];
        out[11] = diag[3];
      });
      kernel.launch(out);
      ctx.sync();
      expectClose("kernel_det", out.read(0), 10.0);
      expectClose("kernel_inv_00", out.read(1), 0.6);
      expectClose("kernel_inv_01", out.read(2), -0.7);
      expectClose("kernel_inv_10", out.read(3), -0.2);
      expectClose("kernel_inv_11", out.read(4), 0.4);
      expectClose("kernel_trace", out.read(5), 10.0);
      expectClose("kernel_frobenius", out.read(6), 105.0);
      expectClose("kernel_diag", out.read(7), 6.0);
      expectClose("kernel_matvec0", out.read(8), 18.0);
      expectClose("kernel_matvec1", out.read(9), 14.0);
      expectClose("kernel_outer", out.read(10), 4.0);
      expectClose("kernel_diag_matrix", out.read(11), 2.0);
    } catch (e:Dynamic) {
      TestRuntimeSupport.closeKernel(kernel);
      out.close();
      throw e;
    }
    TestRuntimeSupport.closeKernel(kernel);
    out.close();
  }

  public static function run():Void {
    testHostLinalg();
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testKernelLinalg(ctx);
    });
  }
}
