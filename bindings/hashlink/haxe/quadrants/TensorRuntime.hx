package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;

class TensorRuntime implements TensorHandle {
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  var handle:QNdarray;
  public var gradTensor:TensorHandle = null;
  public var dualTensor:TensorHandle = null;
  public var needsGrad(default, null):Bool = false;
  var closed:Bool = false;

  public function new(context:Context, dtype:DType, shape:Array<Int>, ?existingHandle:QNdarray) {
    this.context = context;
    this.shape = TensorStorage.validateShape(shape);
    this.dtype = dtype;
    this.handle = existingHandle == null ? TensorStorage.create(context, dtype, this.shape) : existingHandle;
  }

  public function nativeHandle():QNdarray {
    if (closed) {
      throw "Quadrants tensor is closed";
    }
    return handle;
  }

  @:noCompletion public function adoptImportedHandle(importedHandle:QNdarray):Void {
    if (closed) {
      throw "Quadrants tensor is closed";
    }
    Native.ndarray_close(handle);
    handle = importedHandle;
    gradTensor = null;
    dualTensor = null;
  }

  public function close():Void {
    if (!closed) {
      Native.ndarray_close(handle);
      closed = true;
    }
  }

  public function enableGradFlag(enabled:Bool):Void {
    needsGrad = enabled;
    if (!enabled) {
      Native.ndarray_clear_autodiff_handles(nativeHandle());
      gradTensor = null;
      dualTensor = null;
    }
  }

  public function supportsZeroCopy():Bool {
    return Native.ndarray_supports_zero_copy(context.nativeHandle()) != 0;
  }

  public function supportsExternalPointerImport():Bool {
    return Native.ndarray_supports_external_pointer_import(context.nativeHandle()) != 0;
  }

  public function supportsDLPack():Bool {
    return supportsZeroCopy();
  }

  public function exportDLPack():DLPackTensor {
    return new DLPackTensor(Native.ndarray_export_dlpack(context.nativeHandle(), nativeHandle()));
  }


  public function exportDevicePointer():haxe.Int64 {
    return Native.ndarray_export_device_pointer(context.nativeHandle(), nativeHandle());
  }

  public function flatIndex(indices:Array<Int>):Int {
    return TensorStorage.flatIndex(shape, indices);
  }

  public function elementCount():Int {
    return TensorStorage.elementCount(shape);
  }

  public function readBytes(out:hl.Bytes, flatStart:Int, count:Int, outByteOffset:Int = 0):Void {
    TensorStorage.requireByteRange(out, outByteOffset, count);
    Native.ndarray_read_bytes(context.nativeHandle(), nativeHandle(), dtype, flatStart, count, out, outByteOffset);
  }

  public function writeBytes(input:hl.Bytes, flatStart:Int, count:Int, inputByteOffset:Int = 0):Void {
    TensorStorage.requireByteRange(input, inputByteOffset, count);
    Native.ndarray_write_bytes(context.nativeHandle(), nativeHandle(), dtype, flatStart, count, input, inputByteOffset);
  }

  public function copyToBytes(out:hl.Bytes, flatStart:Int = 0, count:Int = -1, outByteOffset:Int = 0):Void {
    var elementTotal = count < 0 ? elementCount() - flatStart : count;
    TensorStorage.requireByteRange(out, outByteOffset, elementTotal);
    readBytes(out, flatStart, elementTotal, outByteOffset);
  }

  public function copyFromBytes(input:hl.Bytes, flatStart:Int = 0, count:Int = -1, inputByteOffset:Int = 0):Void {
    var elementTotal = count < 0 ? elementCount() - flatStart : count;
    TensorStorage.requireByteRange(input, inputByteOffset, elementTotal);
    writeBytes(input, flatStart, elementTotal, inputByteOffset);
  }
}
