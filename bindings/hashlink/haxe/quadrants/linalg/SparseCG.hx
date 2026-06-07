package quadrants.linalg;

import quadrants.Native;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;

class SparseCG {
  public static function solve<T>(matrix:SparseMatrix<T>, b:Tensor<T>, x:Tensor<T>, maxIterations:Int = 128, tolerance:Float = 1.0e-5):Int {
    requireTensorContext(matrix, b, matrix.rows, "rhs");
    requireTensorContext(matrix, x, matrix.cols, "solution");
    return switch (matrix.dtype) {
      case DType.F32:
        Native.sparse_cg_solve_f32(matrix.context.nativeHandle(), matrix.nativeHandle(), (cast b : TensorRuntime).nativeHandle(), (cast x : TensorRuntime).nativeHandle(), maxIterations, tolerance);
      case DType.F64:
        Native.sparse_cg_solve_f64(matrix.context.nativeHandle(), matrix.nativeHandle(), (cast b : TensorRuntime).nativeHandle(), (cast x : TensorRuntime).nativeHandle(), maxIterations, tolerance);
      default:
        throw "Quadrants sparse CG supports only F32 and F64";
    };
  }

  static function requireTensorContext<T>(matrix:SparseMatrix<T>, tensor:Tensor<T>, minElements:Int, name:String):TensorRuntime {
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != matrix.context) {
      throw 'Quadrants sparse CG ${name} tensor belongs to a different context';
    }
    if (runtime.dtype != matrix.dtype) {
      throw 'Quadrants sparse CG ${name} tensor dtype mismatch';
    }
    if (runtime.elementCount() < minElements) {
      throw 'Quadrants sparse CG ${name} tensor is too small';
    }
    return runtime;
  }
}