import quadrants.Context;
import quadrants.Kernel;
import quadrants.Mat2;
import quadrants.Matrix;
import quadrants.Struct;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.Vec3;
import quadrants.Vector;

class TestKernelFeatureRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var kernels:Array<Kernel> = [];
      try {
        var special = new Tensor<F32>(ctx, [2]);
        special.write(0, Math.NaN);
        special.write(1, 1.0 / 0.0);

        var featureOut = new Tensor<I32>(ctx, [6]);
        featureOut.fill(0);
        var featureKernel = Kernel.build(ctx, macro (out:Tensor<I32>, special:Tensor<F32>, flag:Bool, n:Int) -> {
          blockDim(64);
          parallelize(2);
          serialize();
          assert(n == out.shape(0), "kernel feature shape mismatch");
          for (i in 0...n) {
            out[i] = 0;
          }
          var v = Vec3.i32(1, 2, 3);
          var w = Vector.ofArray([4, 5, 6]);
          var s = v + w;
          var a = Mat2.i32(1, 2, 3, 4);
          var b = Matrix.ofArray(2, 2, [5, 6, 7, 8]);
          var c = a.matmul(b);
          var t = c.transpose();
          t[0][1] = t[0][1] + c[1][0];
          var particle = Struct.of2("mass", 2, "velocity", 3);
          particle.mass += particle.velocity;
          var extended = Struct.of5("a", 1, "b", 2, "c", 3, "d", 4, "e", 5);
          extended.e += extended.d;
          var inner = Struct.of2("mass", 2, "velocity", 3);
          var outer = Struct.of2("particle", inner, "id", 4);
          outer.particle.mass += outer.id;
          var big:quadrants.Types.I64 = 0x100000000;
          var single:quadrants.Types.F32 = 1;
          out[0] = s[1];
          out[1] = t[0][1];
          out[2] = particle.mass + extended.e;
          out[3] = outer.particle.mass + outer.particle.velocity;
          out[4] = select(flag, 3, 4) + select(isnan(special[0]), 1, 0) + select(isinf(special[1]), 2, 0);
          out[5] = (big > 0 ? 1 : 0) + (single > 0.0 ? 1 : 0);
        });
        kernels.push(featureKernel);
        featureKernel.launch(featureOut, special, true, 6);
        ctx.sync();
        expectEq("feature_vector", featureOut.read(0), 7);
        expectEq("feature_matrix", featureOut.read(1), 86);
        expectEq("feature_struct", featureOut.read(2), 14);
        expectEq("feature_nested_struct", featureOut.read(3), 9);
        expectEq("feature_select_predicates", featureOut.read(4), 3);
        expectEq("feature_typed_constants", featureOut.read(5), 2);

        var randomOut = new Tensor<I32>(ctx, [2]);
        randomOut.fill(0);
        var randomKernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
          out[0] = randI32();
          out[1] = (randU32() : I32);
        });
        kernels.push(randomKernel);
        ctx.setRandomSeed(12345);
        randomKernel.launch(randomOut);
        ctx.sync();
        if (randomOut.read(0) == 0 && randomOut.read(1) == 0) {
          throw "feature_random_outputs unexpectedly all zero";
        }
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
    });
  }
}
