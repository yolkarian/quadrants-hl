import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.linalg.SparseCG;
import quadrants.linalg.SparseMatrixBuilder;
import quadrants.linalg.SparseOrdering;
import quadrants.linalg.SparseSolver;
import quadrants.linalg.SparseSolverType;
import quadrants.profiler.ProfilerBridge;
import quadrants.profiler.ScopedProfiler;

class TestSparseProfilerBridgeRuntime {
  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function expectClose(name:String, got:Float, expected:Float, tolerance:Float = 1.0e-4):Void {
    var diff = Math.abs(got - expected);
    if (diff > tolerance) throw '${name}: ${got} != ${expected}';
  }

  static function testSparse(ctx:Context):Void {
    var builder = new SparseMatrixBuilder<F32>(ctx, 2, 2);
    var b = new Tensor<F32>(ctx, [2]);
    var y = new Tensor<F32>(ctx, [2]);
    var x = new Tensor<F32>(ctx, [2]);
    var cg = new Tensor<F32>(ctx, [2]);
    var solver:SparseSolver<F32> = null;
    try {
      builder.set(0, 0, 4.0).set(0, 1, 1.0).set(1, 0, 1.0).set(1, 1, 3.0);
      var matrix = builder.build();
      expectTrue("sparse_nnz", matrix.nnz == 4);
      expectClose("sparse_get", matrix.get(1, 1), 3.0);
      var dense = matrix.toDense();
      expectClose("sparse_dense_0", dense[0], 4.0);
      expectClose("sparse_dense_3", dense[3], 3.0);

      b.fromArray([1.0, 2.0]);
      matrix.matVec(b, y);
      expectClose("sparse_matvec_0", y.read(0), 6.0);
      expectClose("sparse_matvec_1", y.read(1), 7.0);

      solver = new SparseSolver<F32>(ctx, DType.F32, SparseSolverType.LU, SparseOrdering.COLAMD, true);
      expectTrue("sparse_compute", solver.compute(matrix));
      solver.solve(matrix, b, x);
      expectClose("sparse_solve_0", x.read(0), 1.0 / 11.0);
      expectClose("sparse_solve_1", x.read(1), 7.0 / 11.0);

      var iterations = SparseCG.solve(matrix, b, cg, 16, 1.0e-5);
      expectTrue("sparse_cg_iterations", iterations > 0);
      expectClose("sparse_cg_0", cg.read(0), 1.0 / 11.0, 1.0e-3);
      expectClose("sparse_cg_1", cg.read(1), 7.0 / 11.0, 1.0e-3);

      solver.close();
      matrix.close();
      b.close();
      y.close();
      x.close();
      cg.close();
    } catch (e:Dynamic) {
      if (solver != null) solver.close();
      b.close();
      y.close();
      x.close();
      cg.close();
      throw e;
    }
  }

  static function testProfilerBridge():Void {
    TestRuntimeSupport.closeSharedContexts();
    var ctx = new Context(Arch.Cpu, true);
    try {
      var features = ProfilerBridge.features(ctx);
      expectTrue("profiler_enabled", features.enabled);
      expectTrue("profiler_scoped", features.scoped);
      expectTrue("profiler_kernel", features.kernel);
      if (features.memory) throw "profiler_memory_unexpected";
      ScopedProfiler.run(ctx, "manual_scope", function() {
        var total = 0;
        for (i in 0...8) total += i;
        return total;
      });
      expectTrue("profiler_total_time", ctx.profiler().totalTime() >= 0.0);
      ctx.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testSparse(ctx);
    });
    testProfilerBridge();
  }
}
