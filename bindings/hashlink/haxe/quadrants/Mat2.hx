package quadrants;

import quadrants.Types.F16;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class Mat2 {
  public static inline function i32(m00:I32, m01:I32, m10:I32, m11:I32):Matrix<I32> return new Matrix(2, 2, [m00, m01, m10, m11]);
  public static inline function u32(m00:U32, m01:U32, m10:U32, m11:U32):Matrix<U32> return new Matrix(2, 2, [m00, m01, m10, m11]);
  public static inline function f16(m00:F16, m01:F16, m10:F16, m11:F16):Matrix<F16> return new Matrix(2, 2, [m00, m01, m10, m11]);
  public static inline function f32(m00:F32, m01:F32, m10:F32, m11:F32):Matrix<F32> return new Matrix(2, 2, [m00, m01, m10, m11]);
  public static inline function f64(m00:F64, m01:F64, m10:F64, m11:F64):Matrix<F64> return new Matrix(2, 2, [m00, m01, m10, m11]);
}
