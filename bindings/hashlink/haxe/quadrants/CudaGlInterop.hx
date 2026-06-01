package quadrants;

/**
 * CUDA/OpenGL interop helpers for HashLink renderers.
 *
 * The OpenGL buffer handle is intentionally typed as Dynamic so Quadrants does
 * not depend on hlsdl at the Haxe package level. hlsdl's `sdl.GL.Buffer` can be
 * passed directly.
 */
class CudaGlInterop {
  /** Returns true when this Quadrants runtime can register OpenGL buffers with the CUDA context. */
  public static function available(context:Context):Bool {
    try {
      return Native.cuda_gl_interop_available(context.nativeHandle()) != 0;
    } catch (_:Dynamic) {
      return false;
    }
  }

  /** Registers an OpenGL buffer with CUDA. The buffer must stay alive until unregister/dispose. */
  public static function registerBuffer(context:Context, glBuffer:Dynamic, byteSize:Int):CudaGlResource {
    if (byteSize <= 0) {
      throw "Quadrants CUDA/GL registration byte size must be positive";
    }
    return new CudaGlResource(context, Native.cuda_gl_register_buffer(context.nativeHandle(), glBuffer, byteSize));
  }
}
