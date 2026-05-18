package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;

class Tensor<T> {
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  final handle:QNdarray;

  public function new(context:Context, handle:QNdarray, shape:Array<Int>, dtype:DType) {
    this.context = context;
    this.handle = handle;
    this.shape = shape;
    this.dtype = dtype;
  }

  public function nativeHandle():QNdarray {
    return handle;
  }

  public function flatIndex(indices:Array<Int>):Int {
    if (indices.length != shape.length) {
      throw "Quadrants tensor index rank mismatch";
    }
    var flat = 0;
    for (i in 0...indices.length) {
      if (indices[i] < 0 || indices[i] >= shape[i]) {
        throw "Quadrants tensor index out of bounds";
      }
      flat = flat * shape[i] + indices[i];
    }
    return flat;
  }

  function flatIndexOptional(i:Int, ?j:Int, ?k:Int, ?l:Int):Int {
    if (j == null) return i;
    if (k == null) return flatIndex([i, j]);
    if (l == null) return flatIndex([i, j, k]);
    return flatIndex([i, j, k, l]);
  }

  public function fillI8(value:Int):Void Native.ndarray_fill_i8(context.nativeHandle(), handle, value);
  public function readI8(flatIndex:Int):Int return Native.ndarray_read_i8(context.nativeHandle(), handle, flatIndex);
  public function writeI8(flatIndex:Int, value:Int):Void Native.ndarray_write_i8(context.nativeHandle(), handle, flatIndex, value);

  public function fillI16(value:Int):Void Native.ndarray_fill_i16(context.nativeHandle(), handle, value);
  public function readI16(flatIndex:Int):Int return Native.ndarray_read_i16(context.nativeHandle(), handle, flatIndex);
  public function writeI16(flatIndex:Int, value:Int):Void Native.ndarray_write_i16(context.nativeHandle(), handle, flatIndex, value);

  public function fillI32(value:Int):Void Native.ndarray_fill_i32(context.nativeHandle(), handle, value);
  public function readI32(i:Int, ?j:Int, ?k:Int, ?l:Int):Int return Native.ndarray_read_i32(context.nativeHandle(), handle, flatIndexOptional(i, j, k, l));
  public function writeI32(flatIndex:Int, value:Int):Void Native.ndarray_write_i32(context.nativeHandle(), handle, flatIndex, value);
  public function readI32At(indices:Array<Int>):Int return readI32(flatIndex(indices));
  public function writeI32At(indices:Array<Int>, value:Int):Void writeI32(flatIndex(indices), value);

  public function fillI64(value:haxe.Int64):Void Native.ndarray_fill_i64(context.nativeHandle(), handle, value);
  public function readI64(flatIndex:Int):haxe.Int64 return Native.ndarray_read_i64(context.nativeHandle(), handle, flatIndex);
  public function writeI64(flatIndex:Int, value:haxe.Int64):Void Native.ndarray_write_i64(context.nativeHandle(), handle, flatIndex, value);

  public function fillU8(value:Int):Void Native.ndarray_fill_u8(context.nativeHandle(), handle, value);
  public function readU8(flatIndex:Int):Int return Native.ndarray_read_u8(context.nativeHandle(), handle, flatIndex);
  public function writeU8(flatIndex:Int, value:Int):Void Native.ndarray_write_u8(context.nativeHandle(), handle, flatIndex, value);

  public function fillU16(value:Int):Void Native.ndarray_fill_u16(context.nativeHandle(), handle, value);
  public function readU16(flatIndex:Int):Int return Native.ndarray_read_u16(context.nativeHandle(), handle, flatIndex);
  public function writeU16(flatIndex:Int, value:Int):Void Native.ndarray_write_u16(context.nativeHandle(), handle, flatIndex, value);

  public function fillU32(value:haxe.Int64):Void Native.ndarray_fill_u32(context.nativeHandle(), handle, value);
  public function readU32(flatIndex:Int):haxe.Int64 return Native.ndarray_read_u32(context.nativeHandle(), handle, flatIndex);
  public function writeU32(flatIndex:Int, value:haxe.Int64):Void Native.ndarray_write_u32(context.nativeHandle(), handle, flatIndex, value);

  public function fillU64(value:haxe.Int64):Void Native.ndarray_fill_u64(context.nativeHandle(), handle, value);
  public function readU64(flatIndex:Int):haxe.Int64 return Native.ndarray_read_u64(context.nativeHandle(), handle, flatIndex);
  public function writeU64(flatIndex:Int, value:haxe.Int64):Void Native.ndarray_write_u64(context.nativeHandle(), handle, flatIndex, value);

  public function fillF32(value:Float):Void Native.ndarray_fill_f32(context.nativeHandle(), handle, value);
  public function readF32(i:Int, ?j:Int, ?k:Int, ?l:Int):Float return Native.ndarray_read_f32(context.nativeHandle(), handle, flatIndexOptional(i, j, k, l));
  public function writeF32(flatIndex:Int, value:Float):Void Native.ndarray_write_f32(context.nativeHandle(), handle, flatIndex, value);
  public function readF32At(indices:Array<Int>):Float return readF32(flatIndex(indices));
  public function writeF32At(indices:Array<Int>, value:Float):Void writeF32(flatIndex(indices), value);

  public function fillF64(value:Float):Void Native.ndarray_fill_f64(context.nativeHandle(), handle, value);
  public function readF64(i:Int, ?j:Int, ?k:Int, ?l:Int):Float return Native.ndarray_read_f64(context.nativeHandle(), handle, flatIndexOptional(i, j, k, l));
  public function writeF64(flatIndex:Int, value:Float):Void Native.ndarray_write_f64(context.nativeHandle(), handle, flatIndex, value);
  public function readF64At(indices:Array<Int>):Float return readF64(flatIndex(indices));
  public function writeF64At(indices:Array<Int>, value:Float):Void writeF64(flatIndex(indices), value);
}
