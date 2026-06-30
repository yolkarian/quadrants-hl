package quadrants.internal;

import quadrants.BufferView;
import quadrants.FieldArg;
import quadrants.Spec;
import quadrants.StructField;
import quadrants.StructTensor;
import quadrants.Tensor;
import quadrants.mesh.MeshAttribute;
import quadrants.mesh.MeshRelation;
import quadrants.quant.QuantizedF32Tensor;
import quadrants.Types.F16;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I8;
import quadrants.Types.I16;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U1;
import quadrants.Types.U8;
import quadrants.Types.U16;
import quadrants.Types.U32;
import quadrants.Types.U64;

class ArgWriter {
  public static inline function tensorI8(buf:ArgBuffer, value:Tensor<I8>):Void buf.addValue(value);
  public static inline function tensorI16(buf:ArgBuffer, value:Tensor<I16>):Void buf.addValue(value);
  public static inline function tensorI32(buf:ArgBuffer, value:Tensor<I32>):Void buf.addValue(value);
  public static inline function tensorI64(buf:ArgBuffer, value:Tensor<I64>):Void buf.addValue(value);
  public static inline function tensorU8(buf:ArgBuffer, value:Tensor<U8>):Void buf.addValue(value);
  public static inline function tensorU16(buf:ArgBuffer, value:Tensor<U16>):Void buf.addValue(value);
  public static inline function tensorU32(buf:ArgBuffer, value:Tensor<U32>):Void buf.addValue(value);
  public static inline function tensorU64(buf:ArgBuffer, value:Tensor<U64>):Void buf.addValue(value);
  public static inline function tensorU1(buf:ArgBuffer, value:Tensor<U1>):Void buf.addValue(value);
  public static inline function tensorF16(buf:ArgBuffer, value:Tensor<F16>):Void buf.addValue(value);
  public static inline function tensorF32(buf:ArgBuffer, value:Tensor<F32>):Void buf.addValue(value);
  public static inline function tensorF64(buf:ArgBuffer, value:Tensor<F64>):Void buf.addValue(value);

  public static inline function fieldI8(buf:ArgBuffer, value:FieldArg<I8>):Void buf.addValue(value);
  public static inline function fieldI16(buf:ArgBuffer, value:FieldArg<I16>):Void buf.addValue(value);
  public static inline function fieldI32(buf:ArgBuffer, value:FieldArg<I32>):Void buf.addValue(value);
  public static inline function fieldI64(buf:ArgBuffer, value:FieldArg<I64>):Void buf.addValue(value);
  public static inline function fieldU8(buf:ArgBuffer, value:FieldArg<U8>):Void buf.addValue(value);
  public static inline function fieldU16(buf:ArgBuffer, value:FieldArg<U16>):Void buf.addValue(value);
  public static inline function fieldU32(buf:ArgBuffer, value:FieldArg<U32>):Void buf.addValue(value);
  public static inline function fieldU64(buf:ArgBuffer, value:FieldArg<U64>):Void buf.addValue(value);
  public static inline function fieldU1(buf:ArgBuffer, value:FieldArg<U1>):Void buf.addValue(value);
  public static inline function fieldF16(buf:ArgBuffer, value:FieldArg<F16>):Void buf.addValue(value);
  public static inline function fieldF32(buf:ArgBuffer, value:FieldArg<F32>):Void buf.addValue(value);
  public static inline function fieldF64(buf:ArgBuffer, value:FieldArg<F64>):Void buf.addValue(value);

  public static inline function bufferViewI8(buf:ArgBuffer, value:BufferView<I8>):Void buf.addValue(value);
  public static inline function bufferViewI16(buf:ArgBuffer, value:BufferView<I16>):Void buf.addValue(value);
  public static inline function bufferViewI32(buf:ArgBuffer, value:BufferView<I32>):Void buf.addValue(value);
  public static inline function bufferViewI64(buf:ArgBuffer, value:BufferView<I64>):Void buf.addValue(value);
  public static inline function bufferViewU8(buf:ArgBuffer, value:BufferView<U8>):Void buf.addValue(value);
  public static inline function bufferViewU16(buf:ArgBuffer, value:BufferView<U16>):Void buf.addValue(value);
  public static inline function bufferViewU32(buf:ArgBuffer, value:BufferView<U32>):Void buf.addValue(value);
  public static inline function bufferViewU64(buf:ArgBuffer, value:BufferView<U64>):Void buf.addValue(value);
  public static inline function bufferViewU1(buf:ArgBuffer, value:BufferView<U1>):Void buf.addValue(value);
  public static inline function bufferViewF16(buf:ArgBuffer, value:BufferView<F16>):Void buf.addValue(value);
  public static inline function bufferViewF32(buf:ArgBuffer, value:BufferView<F32>):Void buf.addValue(value);
  public static inline function bufferViewF64(buf:ArgBuffer, value:BufferView<F64>):Void buf.addValue(value);

  public static inline function scalarI8(buf:ArgBuffer, value:Int):Void buf.addValue(value);
  public static inline function scalarI16(buf:ArgBuffer, value:Int):Void buf.addValue(value);
  public static inline function scalarI32(buf:ArgBuffer, value:Int):Void buf.addValue(value);
  public static inline function scalarI64(buf:ArgBuffer, value:haxe.Int64):Void buf.addValue(value);
  public static inline function scalarU8(buf:ArgBuffer, value:Int):Void buf.addValue(value);
  public static inline function scalarU16(buf:ArgBuffer, value:Int):Void buf.addValue(value);
  public static inline function scalarU32(buf:ArgBuffer, value:haxe.Int64):Void buf.addValue(value);
  public static inline function scalarU64(buf:ArgBuffer, value:haxe.Int64):Void buf.addValue(value);
  public static inline function scalarU1(buf:ArgBuffer, value:Bool):Void buf.addValue(value);
  public static inline function scalarF16(buf:ArgBuffer, value:Float):Void buf.addValue(value);
  public static inline function scalarF32(buf:ArgBuffer, value:F32):Void buf.addValue(value);
  public static inline function scalarF64(buf:ArgBuffer, value:Float):Void buf.addValue(value);
  public static inline function scalarBool(buf:ArgBuffer, value:Bool):Void buf.addValue(value);

  public static function structTensor<S>(buf:ArgBuffer, value:StructTensor<S>):Void {
    for (name in value.members()) {
      buf.addValue(value.member(name));
    }
  }

  public static function structField<S>(buf:ArgBuffer, value:StructField<S>):Void {
    for (name in value.members()) {
      buf.addValue(value.member(name));
    }
  }

  public static inline function meshRelation<From, To>(buf:ArgBuffer, value:MeshRelation<From, To>):Void buf.addValue(value);
  public static inline function meshAttribute<Element, Value>(buf:ArgBuffer, value:MeshAttribute<Element, Value>):Void buf.addValue(value);
  public static inline function quantizedF32Tensor(buf:ArgBuffer, value:QuantizedF32Tensor):Void buf.addValue(value);

  public static inline function spec<T>(buf:ArgBuffer, value:Spec<T>):Void buf.addSpec(value.value());
  public static inline function value<T>(buf:ArgBuffer, value:T):Void buf.addValue(value);
}
