package quadrants;

import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Native.QContext;

class Context {
  final handle:QContext;
  var closed:Bool = false;

  public function new(arch:Arch = Cpu) {
    Native.ensureConfigured();
    handle = Native.context_create(arch);
  }

  public function nativeHandle():QContext {
    if (closed) {
      throw "Quadrants context is closed";
    }
    return handle;
  }

  public function sync():Void {
    Native.context_sync(nativeHandle());
  }

  public function close():Void {
    if (!closed) {
      Native.context_close(handle);
      closed = true;
    }
  }

  public function ndarray<T>(dtype:DType, shape:Array<Int>):Tensor<T> {
    if (shape.length == 0) {
      throw "Quadrants ndarray shape must have at least one dimension";
    }
    var nativeShape = new hl.NativeArray<Int>(shape.length);
    for (i in 0...shape.length) {
      if (shape[i] <= 0) {
        throw "Quadrants ndarray shape dimensions must be positive";
      }
      nativeShape[i] = shape[i];
    }
    return new Tensor<T>(this, Native.ndarray_create(nativeHandle(), dtype, nativeShape), shape.copy(), dtype);
  }

  public function ndarrayI8(shape:Array<Int>):Tensor<Int> return ndarray(DType.I8, shape);
  public function ndarrayI16(shape:Array<Int>):Tensor<Int> return ndarray(DType.I16, shape);
  public function ndarrayI32(shape:Array<Int>):Tensor<Int> return ndarray(DType.I32, shape);
  public function ndarrayI64(shape:Array<Int>):Tensor<haxe.Int64> return ndarray(DType.I64, shape);
  public function ndarrayU8(shape:Array<Int>):Tensor<Int> return ndarray(DType.U8, shape);
  public function ndarrayU16(shape:Array<Int>):Tensor<Int> return ndarray(DType.U16, shape);
  public function ndarrayU32(shape:Array<Int>):Tensor<haxe.Int64> return ndarray(DType.U32, shape);
  public function ndarrayU64(shape:Array<Int>):Tensor<haxe.Int64> return ndarray(DType.U64, shape);
  public function ndarrayF32(shape:Array<Int>):Tensor<quadrants.Types.F32> return ndarray(DType.F32, shape);
  public function ndarrayF64(shape:Array<Int>):Tensor<quadrants.Types.F64> return ndarray(DType.F64, shape);
}
