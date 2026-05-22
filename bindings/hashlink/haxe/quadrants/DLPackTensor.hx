package quadrants;

class DLPackTensor {
  public final handle:haxe.Int64;
  var closed:Bool = false;

  public function new(handle:haxe.Int64) {
    this.handle = handle;
  }

  function ensureOpen():Void {
    if (closed) {
      throw "Quadrants DLPack tensor is closed";
    }
  }

  public function takeHandle():haxe.Int64 {
    ensureOpen();
    closed = true;
    return handle;
  }

  public function close():Void {
    if (!closed) {
      Native.dlpack_release(handle);
      closed = true;
    }
  }

  public function deviceType():Int {
    ensureOpen();
    return Native.dlpack_device_type(handle);
  }

  public function deviceId():Int {
    ensureOpen();
    return Native.dlpack_device_id(handle);
  }

  public function dtypeCode():Int {
    ensureOpen();
    return Native.dlpack_dtype_code(handle);
  }

  public function dtypeBits():Int {
    ensureOpen();
    return Native.dlpack_dtype_bits(handle);
  }

  public function dtypeLanes():Int {
    ensureOpen();
    return Native.dlpack_dtype_lanes(handle);
  }

  public function ndim():Int {
    ensureOpen();
    return Native.dlpack_ndim(handle);
  }

  public function shape(axis:Int):haxe.Int64 {
    ensureOpen();
    return Native.dlpack_shape(handle, axis);
  }

  public function stride(axis:Int):haxe.Int64 {
    ensureOpen();
    return Native.dlpack_stride(handle, axis);
  }

  public function dataPointer():haxe.Int64 {
    ensureOpen();
    return Native.dlpack_data_pointer(handle);
  }
}
