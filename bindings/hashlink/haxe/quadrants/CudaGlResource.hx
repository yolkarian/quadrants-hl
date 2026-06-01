package quadrants;

import quadrants.Native.QCudaGlResource;

/** Registered CUDA/OpenGL buffer resource. */
class CudaGlResource {
  public final context:Context;
  final handle:QCudaGlResource;
  var mapped:Bool = false;
  var closed:Bool = false;

  public function new(context:Context, handle:QCudaGlResource) {
    this.context = context;
    this.handle = handle;
  }

  inline function ensureOpen():Void {
    if (closed) {
      throw "Quadrants CUDA/GL resource is closed";
    }
  }

  /** Maps the OpenGL buffer and returns a CUDA device pointer valid until unmap/dispose. */
  public function map():haxe.Int64 {
    ensureOpen();
    var pointer = Native.cuda_gl_map(context.nativeHandle(), handle);
    mapped = true;
    return pointer;
  }

  /** Unmaps the OpenGL buffer after device writes are finished. Safe to call when already unmapped. */
  public function unmap():Void {
    ensureOpen();
    Native.cuda_gl_unmap(context.nativeHandle(), handle);
    mapped = false;
  }

  /** Unregisters the resource. Disposing a mapped resource unmaps it in native code first. */
  public function dispose():Void {
    if (!closed) {
      Native.cuda_gl_unregister(handle);
      mapped = false;
      closed = true;
    }
  }

  /** Alias for dispose(), matching other Quadrants resource wrappers. */
  public inline function close():Void {
    dispose();
  }
}
