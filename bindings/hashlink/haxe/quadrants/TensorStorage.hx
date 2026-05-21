package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;

class TensorStorage {
  public static function validateShape(shape:Array<Int>):Array<Int> {
    if (shape.length == 0) {
      throw "Quadrants ndarray shape must have at least one dimension";
    }
    var result = shape.copy();
    for (dim in result) {
      if (dim <= 0) {
        throw "Quadrants ndarray shape dimensions must be positive";
      }
    }
    return result;
  }

  public static function create(context:Context, dtype:DType, shape:Array<Int>):QNdarray {
    var nativeShape = new hl.NativeArray<Int>(shape.length);
    for (i in 0...shape.length) {
      nativeShape[i] = shape[i];
    }
    return Native.ndarray_create(context.nativeHandle(), dtype, nativeShape);
  }

  public static function flatIndex(shape:Array<Int>, indices:Array<Int>):Int {
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

  public static function indicesFromFlat(shape:Array<Int>, flatIndex:Int):Array<Int> {
    var total = elementCount(shape);
    if (flatIndex < 0 || flatIndex >= total) {
      throw "Quadrants tensor flat index out of bounds";
    }
    var remaining = flatIndex;
    var indices = [for (_ in 0...shape.length) 0];
    var axis = shape.length;
    while (axis > 0) {
      axis--;
      var dim = shape[axis];
      indices[axis] = remaining % dim;
      remaining = Std.int(remaining / dim);
    }
    return indices;
  }

  public static function nativeIntArray(values:Array<Int>):hl.NativeArray<Int> {
    var native = new hl.NativeArray<Int>(values.length);
    for (i in 0...values.length) {
      native[i] = values[i];
    }
    return native;
  }

  public static function elementCount(shape:Array<Int>):Int {
    var count = 1;
    for (dim in shape) {
      count *= dim;
    }
    return count;
  }

  public static function requireElementCount(shape:Array<Int>, count:Int):Void {
    if (count != elementCount(shape)) {
      throw "Quadrants tensor host array length mismatch";
    }
  }

  public static function requireByteRange(buffer:hl.Bytes, byteOffset:Int, count:Int):Void {
    if (byteOffset < 0) {
      throw "Quadrants tensor byte offset must be non-negative";
    }
    if (count < 0) {
      throw "Quadrants tensor byte element count must be non-negative";
    }
  }
}
