package quadrants.linalg;

import quadrants.Native;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.F32;

class SparseCG {
  public static function solve(matrix:SparseMatrix, b:Tensor<F32>, x:Tensor<F32>, maxIterations:Int = 128, tolerance:Float = 1.0e-5):Int {
    requireTensorContext(matrix, b, "rhs");
    requireTensorContext(matrix, x, "solution");
    return Native.sparse_cg_solve_f32(matrix.context.nativeHandle(), matrix.nativeHandle(), b.nativeHandle(), x.nativeHandle(), maxIterations, tolerance);
  }

  static function requireTensorContext(matrix:SparseMatrix, tensor:Dynamic, name:String):TensorRuntime {
    if (!Std.isOfType(tensor, TensorRuntime)) {
      throw 'Quadrants sparse CG ${name} must be a Tensor';
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != matrix.context) {
      throw 'Quadrants sparse CG ${name} tensor belongs to a different context';
    }
    return runtime;
  }
}
