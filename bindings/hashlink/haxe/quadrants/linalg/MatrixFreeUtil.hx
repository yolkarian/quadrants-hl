package quadrants.linalg;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;

@:noCompletion
class MatrixFreeUtil {
  public static function requireSupportedDType(dtype:DType):Void {
    switch (dtype) {
      case DType.F32 | DType.F64:
      default:
        throw "Quadrants matrix-free sparse solvers support only F32 and F64 tensors";
    }
  }

  public static function allocateTensor<T>(context:Context, dtype:DType, size:Int):Tensor<T> {
    requireSupportedDType(dtype);
    return switch (dtype) {
      case DType.F32: cast new Tensor<F32>(context, [size]);
      case DType.F64: cast new Tensor<F64>(context, [size]);
      default: throw "Quadrants matrix-free sparse solvers support only F32 and F64 tensors";
    };
  }

  public static function requireVector<T>(context:Context, dtype:DType, size:Int, tensor:Tensor<T>, name:String):Void {
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != context) {
      throw 'Quadrants matrix-free ${name} tensor belongs to a different context';
    }
    if (runtime.dtype != dtype) {
      throw 'Quadrants matrix-free ${name} tensor dtype mismatch';
    }
    if (runtime.elementCount() < size) {
      throw 'Quadrants matrix-free ${name} tensor is too small';
    }
  }

  public static inline function toFloat<T>(value:T):Float {
    return cast value;
  }

  public static inline function fromFloat<T>(value:Float):T {
    return cast value;
  }

  public static function closeTensor<T>(tensor:Tensor<T>):Void {
    var runtime:TensorRuntime = cast tensor;
    runtime.close();
  }
}
