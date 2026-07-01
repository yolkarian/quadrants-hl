import quadrants.Context;
import quadrants.Tensor;
import quadrants.TensorArg;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.linalg.LinearOperator;
import quadrants.linalg.MatrixFreeBICGSTAB;
import quadrants.linalg.MatrixFreeCG;
import quadrants.linalg.SparseBackendFeatures;
import quadrants.linalg.SparseBackendKind;
import quadrants.linalg.SparseCG;
import quadrants.linalg.SparseMatrix;
import quadrants.linalg.SparseMatrixBuilder;
import quadrants.linalg.SparseOrdering;
import quadrants.linalg.SparseSolver;
import quadrants.linalg.SparseSolverType;
import quadrants.linalg.SparseStorageFormat;

class SymmetricF32Operator implements LinearOperator<F32> {
  public function new() {}

  public function apply(x:TensorArg<F32>, y:TensorArg<F32>):Void {
    var x0:Float = x.read(0);
    var x1:Float = x.read(1);
    y.write(0, 4.0 * x0 + x1);
    y.write(1, x0 + 3.0 * x1);
  }
}

class NonSymmetricF32Operator implements LinearOperator<F32> {
  public function new() {}

  public function apply(x:TensorArg<F32>, y:TensorArg<F32>):Void {
    var x0:Float = x.read(0);
    var x1:Float = x.read(1);
    y.write(0, 4.0 * x0 + x1);
    y.write(1, 2.0 * x0 + 3.0 * x1);
  }
}

class TestSparseParityRuntime {
  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function expectClose(name:String, got:Float, expected:Float, tolerance:Float = 1.0e-4):Void {
    var diff = Math.abs(got - expected);
    if (diff > tolerance) throw '${name}: ${got} != ${expected}';
  }

  static function expectThrows(name:String, body:Void->Void):Void {
    var thrown = false;
    try {
      body();
    } catch (_:Dynamic) {
      thrown = true;
    }
    if (!thrown) throw '${name}: expected throw';
  }

  static function testFeatureProbe(ctx:Context):Void {
    var features = SparseBackendFeatures.probe(ctx);
    expectTrue("sparse_features_f32", features.supportsDType(DType.F32));
    expectTrue("sparse_features_f64", features.supportsDType(DType.F64));
    expectTrue("sparse_features_host_reference", features.backend == SparseBackendKind.HostReference && features.hostReferenceBackend);
    if (features.nativeSparseBackend) throw "sparse_native_backend_unexpected";
  }

  static function testF32MatrixOps(ctx:Context):Void {
    var a = new SparseMatrixBuilder<F32>(ctx, 2, 3, DType.F32, SparseStorageFormat.COO, 4)
      .set(0, 0, 1.0)
      .set(0, 2, 2.0)
      .set(1, 1, 3.0)
      .build();
    var b = new SparseMatrixBuilder<F32>(ctx, 2, 3, DType.F32, SparseStorageFormat.CSR, 3)
      .set(0, 1, 4.0)
      .set(0, 2, -2.0)
      .set(1, 0, 5.0)
      .build();
    var x = new Tensor<F32>(ctx, [3]);
    var y = new Tensor<F32>(ctx, [2]);
    var sum:SparseMatrix<F32> = null;
    var diff:SparseMatrix<F32> = null;
    var transpose:SparseMatrix<F32> = null;
    var product:SparseMatrix<F32> = null;
    try {
      x.fromArray([4.0, 5.0, 6.0]);
      a.matVec(x, y);
      expectClose("sparse_f32_matvec_0", y.read(0), 16.0);
      expectClose("sparse_f32_matvec_1", y.read(1), 15.0);

      transpose = a.transpose();
      expectTrue("sparse_transpose_shape", transpose.rows == 3 && transpose.cols == 2);
      expectClose("sparse_transpose_value", transpose.get(2, 0), 2.0);

      sum = a.add(b);
      expectClose("sparse_add_0_1", sum.get(0, 1), 4.0);
      expectClose("sparse_add_cancel", sum.get(0, 2), 0.0);
      expectClose("sparse_add_1_0", sum.get(1, 0), 5.0);

      diff = a.sub(b);
      expectClose("sparse_sub_0_1", diff.get(0, 1), -4.0);
      expectClose("sparse_sub_0_2", diff.get(0, 2), 4.0);
      expectClose("sparse_sub_1_0", diff.get(1, 0), -5.0);

      product = a.mul(transpose);
      expectTrue("sparse_mul_shape", product.rows == 2 && product.cols == 2);
      expectClose("sparse_mul_0_0", product.get(0, 0), 5.0);
      expectClose("sparse_mul_0_1", product.get(0, 1), 0.0);
      expectClose("sparse_mul_1_1", product.get(1, 1), 9.0);
    } catch (e:Dynamic) {
      if (product != null) product.close();
      if (transpose != null) transpose.close();
      if (diff != null) diff.close();
      if (sum != null) sum.close();
      x.close();
      y.close();
      a.close();
      b.close();
      throw e;
    }
    if (product != null) product.close();
    if (transpose != null) transpose.close();
    if (diff != null) diff.close();
    if (sum != null) sum.close();
    x.close();
    y.close();
    a.close();
    b.close();
  }

  static function testF64MatVec(ctx:Context):Void {
    var matrix = new SparseMatrixBuilder<F64>(ctx, 2, 2, DType.F64, SparseStorageFormat.CSR, 3)
      .set(0, 0, 1.5)
      .set(0, 1, -0.5)
      .set(1, 1, 2.0)
      .build();
    var other = new SparseMatrixBuilder<F64>(ctx, 2, 2, DType.F64, SparseStorageFormat.COO, 2)
      .set(0, 1, 0.5)
      .set(1, 0, 4.0)
      .build();
    var x = new Tensor<F64>(ctx, [2]);
    var y = new Tensor<F64>(ctx, [2]);
    var transpose:SparseMatrix<F64> = null;
    var sum:SparseMatrix<F64> = null;
    var diff:SparseMatrix<F64> = null;
    try {
      x.fromArray([2.0, 3.0]);
      matrix.matVec(x, y);
      expectClose("sparse_f64_matvec_0", y.read(0), 1.5, 1.0e-9);
      expectClose("sparse_f64_matvec_1", y.read(1), 6.0, 1.0e-9);
      expectClose("sparse_f64_get", matrix.get(0, 1), -0.5, 1.0e-9);
      transpose = matrix.transpose();
      expectClose("sparse_f64_transpose", transpose.get(1, 0), -0.5, 1.0e-9);
      sum = matrix.add(other);
      expectClose("sparse_f64_add_cancel", sum.get(0, 1), 0.0, 1.0e-9);
      expectClose("sparse_f64_add_new", sum.get(1, 0), 4.0, 1.0e-9);
      diff = matrix.sub(other);
      expectClose("sparse_f64_sub_0_1", diff.get(0, 1), -1.0, 1.0e-9);
      expectClose("sparse_f64_sub_1_0", diff.get(1, 0), -4.0, 1.0e-9);
    } catch (e:Dynamic) {
      if (diff != null) diff.close();
      if (sum != null) sum.close();
      if (transpose != null) transpose.close();
      x.close();
      y.close();
      other.close();
      matrix.close();
      throw e;
    }
    if (diff != null) diff.close();
    if (sum != null) sum.close();
    if (transpose != null) transpose.close();
    x.close();
    y.close();
    other.close();
    matrix.close();
  }

  static function testSolverEnums(ctx:Context):Void {
    var matrix = new SparseMatrixBuilder<F64>(ctx, 2, 2, DType.F64, SparseStorageFormat.CSR, 4)
      .set(0, 0, 4.0)
      .set(0, 1, 1.0)
      .set(1, 0, 1.0)
      .set(1, 1, 3.0)
      .build();
    var b = new Tensor<F64>(ctx, [2]);
    var x = new Tensor<F64>(ctx, [2]);
    var cg = new Tensor<F64>(ctx, [2]);
    var solver:SparseSolver<F64> = null;
    try {
      b.fromArray([1.0, 2.0]);
      var solverTypes = [SparseSolverType.LU, SparseSolverType.LLT, SparseSolverType.LDLT];
      var orderings = [SparseOrdering.COLAMD, SparseOrdering.AMD, SparseOrdering.Natural];
      for (i in 0...solverTypes.length) {
        x.fill(0.0);
        solver = new SparseSolver<F64>(ctx, DType.F64, solverTypes[i], orderings[i], true);
        expectTrue('sparse_solver_compute_${i}', solver.compute(matrix));
        solver.solve(matrix, b, x);
        expectClose('sparse_solver_${i}_0', x.read(0), 1.0 / 11.0, 1.0e-9);
        expectClose('sparse_solver_${i}_1', x.read(1), 7.0 / 11.0, 1.0e-9);
        solver.close();
        solver = null;
      }
      cg.fill(0.0);
      var cgIterations = SparseCG.solve(matrix, b, cg, 16, 1.0e-9);
      expectTrue("sparse_f64_cg_iterations", cgIterations > 0);
      expectClose("sparse_f64_cg_0", cg.read(0), 1.0 / 11.0, 1.0e-7);
      expectClose("sparse_f64_cg_1", cg.read(1), 7.0 / 11.0, 1.0e-7);
      solver = new SparseSolver<F64>(ctx, DType.F64, SparseSolverType.LU, SparseOrdering.Natural, false);
      expectThrows("sparse_solver_requires_explicit_fallback", function() solver.compute(matrix));
      solver.close();
      solver = null;
    } catch (e:Dynamic) {
      if (solver != null) solver.close();
      b.close();
      x.close();
      cg.close();
      matrix.close();
      throw e;
    }
    b.close();
    x.close();
    cg.close();
    matrix.close();
  }

  static function testMatrixFree(ctx:Context):Void {
    var b = new Tensor<F32>(ctx, [2]);
    var x = new Tensor<F32>(ctx, [2]);
    var cg = new MatrixFreeCG<F32>(ctx, DType.F32, 2, new SymmetricF32Operator());
    var bicg = new MatrixFreeBICGSTAB<F32>(ctx, DType.F32, 2, new NonSymmetricF32Operator());
    try {
      b.fromArray([1.0, 2.0]);
      x.fill(0.0);
      var cgIterations = cg.solve(b, x, 16, 1.0e-6);
      expectTrue("matrix_free_cg_converged", cgIterations > 0);
      expectClose("matrix_free_cg_0", x.read(0), 1.0 / 11.0, 1.0e-4);
      expectClose("matrix_free_cg_1", x.read(1), 7.0 / 11.0, 1.0e-4);

      x.fill(0.0);
      var cgFailed = cg.solve(b, x, 1, 1.0e-12);
      expectTrue("matrix_free_cg_failure", cgFailed < 0);

      b.fromArray([1.0, 2.0]);
      x.fill(0.0);
      var bicgIterations = bicg.solve(b, x, 16, 1.0e-6);
      expectTrue("matrix_free_bicgstab_converged", bicgIterations > 0);
      expectClose("matrix_free_bicgstab_0", x.read(0), 0.1, 1.0e-4);
      expectClose("matrix_free_bicgstab_1", x.read(1), 0.6, 1.0e-4);

      x.fill(0.0);
      var bicgFailed = bicg.solve(b, x, 1, 1.0e-12);
      expectTrue("matrix_free_bicgstab_failure", bicgFailed < 0);
    } catch (e:Dynamic) {
      cg.close();
      bicg.close();
      b.close();
      x.close();
      throw e;
    }
    cg.close();
    bicg.close();
    b.close();
    x.close();
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testFeatureProbe(ctx);
      testF32MatrixOps(ctx);
      testF64MatVec(ctx);
      testSolverEnums(ctx);
      testMatrixFree(ctx);
    });
  }

  public static function main():Void {
    run();
    TestRuntimeSupport.closeSharedContexts();
  }
}
