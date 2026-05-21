package quadrants;

import quadrants.Types.F16;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class Mat4 {
  public static inline function i32(m00:I32, m01:I32, m02:I32, m03:I32, m10:I32, m11:I32, m12:I32, m13:I32, m20:I32, m21:I32, m22:I32, m23:I32, m30:I32, m31:I32, m32:I32, m33:I32):Matrix<I32> return new Matrix(4, 4, [m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33]);
  public static inline function u32(m00:U32, m01:U32, m02:U32, m03:U32, m10:U32, m11:U32, m12:U32, m13:U32, m20:U32, m21:U32, m22:U32, m23:U32, m30:U32, m31:U32, m32:U32, m33:U32):Matrix<U32> return new Matrix(4, 4, [m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33]);
  public static inline function f16(m00:F16, m01:F16, m02:F16, m03:F16, m10:F16, m11:F16, m12:F16, m13:F16, m20:F16, m21:F16, m22:F16, m23:F16, m30:F16, m31:F16, m32:F16, m33:F16):Matrix<F16> return new Matrix(4, 4, [m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33]);
  public static inline function f32(m00:F32, m01:F32, m02:F32, m03:F32, m10:F32, m11:F32, m12:F32, m13:F32, m20:F32, m21:F32, m22:F32, m23:F32, m30:F32, m31:F32, m32:F32, m33:F32):Matrix<F32> return new Matrix(4, 4, [m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33]);
  public static inline function f64(m00:F64, m01:F64, m02:F64, m03:F64, m10:F64, m11:F64, m12:F64, m13:F64, m20:F64, m21:F64, m22:F64, m23:F64, m30:F64, m31:F64, m32:F64, m33:F64):Matrix<F64> return new Matrix(4, 4, [m00, m01, m02, m03, m10, m11, m12, m13, m20, m21, m22, m23, m30, m31, m32, m33]);
}
