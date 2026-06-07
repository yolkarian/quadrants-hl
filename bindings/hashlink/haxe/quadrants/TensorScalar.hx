package quadrants;

import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

class TensorScalar {
  public static inline function i32(context:Context):Tensor<I32> return new Tensor<I32>(context, []);
  public static inline function u32(context:Context):Tensor<U32> return new Tensor<U32>(context, []);
  public static inline function i64(context:Context):Tensor<I64> return new Tensor<I64>(context, []);
  public static inline function u64(context:Context):Tensor<U64> return new Tensor<U64>(context, []);
  public static inline function f32(context:Context):Tensor<F32> return new Tensor<F32>(context, []);
  public static inline function f64(context:Context):Tensor<F64> return new Tensor<F64>(context, []);
}
