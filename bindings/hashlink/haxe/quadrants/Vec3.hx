package quadrants;

import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.F16;
import quadrants.Types.I32;
import quadrants.Types.U32;

class Vec3 {
  public static inline function i32(x:I32, y:I32, z:I32):Vector<I32> return Vector.ofArray([x, y, z]);
  public static inline function u32(x:U32, y:U32, z:U32):Vector<U32> return Vector.ofArray([x, y, z]);
  public static inline function f16(x:F16, y:F16, z:F16):Vector<F16> return Vector.ofArray([x, y, z]);
  public static inline function f32(x:F32, y:F32, z:F32):Vector<F32> return Vector.ofArray([x, y, z]);
  public static inline function f64(x:F64, y:F64, z:F64):Vector<F64> return Vector.ofArray([x, y, z]);
}
