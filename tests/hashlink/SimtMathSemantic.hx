import quadrants.Context;
import quadrants.Kernel;
import quadrants.Matrix;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.funcs.Linalg;
import quadrants.simt.SubgroupSegmented;

class SimtMathSemantic {
  static function expectNear(name:String, got:Float, expected:Float, epsilon:Float = 1.0e-6):Void {
    if (Math.abs(got - expected) > epsilon) {
      throw 'SimtMathSemantic ${name} failed: got ${got}, expected ${expected}';
    }
  }

  static function testSymEigGeneral(n:Int, source:Array<Float>, epsilon:Float = 1.0e-6):Void {
    var m:Matrix<Float> = Matrix.ofArray(n, n, source);
    var eig = Linalg.symEigGeneral(m);
    for (i in 0...(n - 1)) {
      if (eig.values[i] > eig.values[i + 1]) {
        throw 'SimtMathSemantic symEigGeneral${n} eigenvalues are not ascending';
      }
    }
    // Reconstruct A = Q diag(lambda) Q^T and compare entrywise.
    for (row in 0...n) {
      for (col in 0...n) {
        var sum = 0.0;
        for (k in 0...n) {
          sum += eig.vectors.get(row, k) * eig.values[k] * eig.vectors.get(col, k);
        }
        expectNear('symEigGeneral${n}_${row}_${col}', sum, source[row * n + col], epsilon);
      }
    }
  }

  static function testSegmentedCpuDegenerate(ctx:Context):Void {
    // CPU subgroups have width 1, so every lane is its own segment head and
    // the segmented reduction must return the lane's own value.
    var input = new Tensor<I32>(ctx, [4]);
    var flags = new Tensor<I32>(ctx, [4]);
    var out = new Tensor<I32>(ctx, [4]);
    input.fromArray([5, 6, 7, 8]);
    flags.fromArray([1, 0, 0, 1]);
    var k = Kernel.build(ctx, macro (a:Tensor<I32>, flags:Tensor<I32>, out:Tensor<I32>) -> {
      for (i in 0...4) {
        out[i] = SubgroupSegmented.segmentedReduceAddI32(a[i], flags[i]);
      }
    }, {helpers: [SubgroupSegmented]});
    k.launch(input, flags, out);
    ctx.sync();
    var values = out.toArray();
    for (i in 0...4) {
      if (values[i] != [5, 6, 7, 8][i]) {
        throw 'SimtMathSemantic segmented_cpu_degenerate lane ${i} failed: got ${values[i]}';
      }
    }
    input.close();
    flags.close();
    out.close();
  }

  public static function run():Void {
    testSymEigGeneral(4, [
      4.0, 1.0, 0.0, 2.0,
      1.0, 5.0, 1.0, 0.0,
      0.0, 1.0, 6.0, 1.0,
      2.0, 0.0, 1.0, 7.0,
    ]);
    testSymEigGeneral(5, [
      10.0, 2.0, 0.0, 1.0, 0.0,
      2.0, 8.0, 3.0, 0.0, 0.0,
      0.0, 3.0, 6.0, 1.0, 2.0,
      1.0, 0.0, 1.0, 9.0, 1.0,
      0.0, 0.0, 2.0, 1.0, 4.0,
    ]);
    // Tiny-scale matrix: an absolute pivot threshold would return the raw
    // diagonal here; the relative threshold must still diagonalize it.
    testSymEigGeneral(4, [
      4.0e-40, 1.0e-40, 0.0, 2.0e-40,
      1.0e-40, 5.0e-40, 1.0e-40, 0.0,
      0.0, 1.0e-40, 6.0e-40, 1.0e-40,
      2.0e-40, 0.0, 1.0e-40, 7.0e-40,
    ], 1.0e-45);
    var spd = Linalg.makeSpd(Matrix.ofArray(4, 4, [
      1.0, 0.0, 0.0, 0.0,
      0.0, -2.0, 0.0, 0.0,
      0.0, 0.0, 3.0, 0.0,
      0.0, 0.0, 0.0, -4.0,
    ]));
    var spdEig = Linalg.symEigGeneral(spd);
    for (i in 0...4) {
      if (spdEig.values[i] < 0.0) {
        throw "SimtMathSemantic makeSpd produced a negative eigenvalue";
      }
    }

    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true});
    try {
      MathHelpersSemantic.run(ctx);
      testSegmentedCpuDegenerate(ctx);
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
    ctx.close();
  }

  static function main():Void {
    run();
    Sys.println("simt math semantic ok");
  }
}
