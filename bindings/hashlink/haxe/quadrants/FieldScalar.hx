package quadrants;

import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

class FieldScalar {
  public static inline function i32(context:Context):Field<I32> return new Field<I32>(context, []);
  public static inline function u32(context:Context):Field<U32> return new Field<U32>(context, []);
  public static inline function i64(context:Context):Field<I64> return new Field<I64>(context, []);
  public static inline function u64(context:Context):Field<U64> return new Field<U64>(context, []);
  public static inline function f32(context:Context):Field<F32> return new Field<F32>(context, []);
  public static inline function f64(context:Context):Field<F64> return new Field<F64>(context, []);
}
