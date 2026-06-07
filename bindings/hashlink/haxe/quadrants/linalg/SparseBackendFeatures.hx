package quadrants.linalg;

import quadrants.Context;
import quadrants.Native;
import quadrants.Types.DType;

class SparseBackendFeatures {
  public final backend:SparseBackendKind;
  public final supportsF32:Bool;
  public final supportsF64:Bool;
  public final nativeSparseBackend:Bool;
  public final hostReferenceBackend:Bool;

  public function new(backend:SparseBackendKind, supportsF32:Bool, supportsF64:Bool, nativeSparseBackend:Bool) {
    this.backend = backend;
    this.supportsF32 = supportsF32;
    this.supportsF64 = supportsF64;
    this.nativeSparseBackend = nativeSparseBackend;
    this.hostReferenceBackend = backend == SparseBackendKind.HostReference;
  }

  public static function probe(context:Context):SparseBackendFeatures {
    var backend:SparseBackendKind = cast Native.sparse_backend_kind(context.nativeHandle());
    return new SparseBackendFeatures(
      backend,
      Native.sparse_supports_dtype(context.nativeHandle(), DType.F32) != 0,
      Native.sparse_supports_dtype(context.nativeHandle(), DType.F64) != 0,
      Native.sparse_supports_native_backend(context.nativeHandle()) != 0
    );
  }

  public function supportsDType(dtype:DType):Bool {
    return switch (dtype) {
      case DType.F32: supportsF32;
      case DType.F64: supportsF64;
      default: false;
    };
  }
}
