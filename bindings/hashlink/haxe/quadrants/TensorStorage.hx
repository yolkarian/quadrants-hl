package quadrants;

import haxe.Int64;
import quadrants.Native.QNdarray;
import quadrants.Types.DType;

class TensorStorage {
  public static function copyIntArray(values:Array<Int>):Array<Int> {
    return [for (value in values) value];
  }

  public static function validateShape(shape:Array<Int>):Array<Int> {
    var result = copyIntArray(shape);
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

  public static function requireSameShape(expected:Array<Int>, actual:Array<Int>, what:String):Void {
    if (expected.length != actual.length) {
      throw 'Quadrants ${what} rank mismatch';
    }
    for (i in 0...expected.length) {
      if (expected[i] != actual[i]) {
        throw 'Quadrants ${what} shape mismatch';
      }
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

  public static function dlpackShape(capsule:DLPackTensor):Array<Int> {
    var rank = capsule.ndim();
    if (rank <= 0) {
      throw "Quadrants DLPack import requires a tensor with at least one dimension";
    }
    var shape = new Array<Int>();
    for (axis in 0...rank) {
      var dim64 = capsule.shape(axis);
      if (Int64.compare(dim64, Int64.make(0, 0)) <= 0) {
        throw "Quadrants DLPack import requires positive dimensions";
      }
      if (Int64.compare(dim64, Int64.make(0, 0x7fffffff)) > 0) {
        throw "Quadrants DLPack import dimension exceeds Haxe Int range";
      }
      shape.push(Int64.toInt(dim64));
    }
    return shape;
  }

  public static function requireContiguousDLPack(capsule:DLPackTensor, shape:Array<Int>):Void {
    var expectedStride = 1;
    var axis = shape.length;
    while (axis > 0) {
      axis--;
      var stride64 = capsule.stride(axis);
      if (Int64.compare(stride64, Int64.make(0, expectedStride)) != 0) {
        throw "Quadrants DLPack import requires a contiguous row-major tensor";
      }
      expectedStride *= shape[axis];
    }
  }

  public static function requireDLPackDType(capsule:DLPackTensor, dtype:DType):Void {
    if (capsule.dtypeLanes() != 1) {
      throw "Quadrants DLPack import requires a scalar-lane tensor";
    }
    var expected = switch (dtype) {
      case DType.I8: {code: 0, bits: 8};
      case DType.I16: {code: 0, bits: 16};
      case DType.I32: {code: 0, bits: 32};
      case DType.I64: {code: 0, bits: 64};
      case DType.U8: {code: 1, bits: 8};
      case DType.U16: {code: 1, bits: 16};
      case DType.U32: {code: 1, bits: 32};
      case DType.U64: {code: 1, bits: 64};
      case DType.F16: {code: 2, bits: 16};
      case DType.F32: {code: 2, bits: 32};
      case DType.F64: {code: 2, bits: 64};
      case DType.U1: {code: 6, bits: 8};
      default: throw "Quadrants DLPack import encountered an unsupported dtype";
    };
    if (capsule.dtypeCode() != expected.code || capsule.dtypeBits() != expected.bits) {
      throw "Quadrants DLPack dtype mismatch";
    }
  }
}
