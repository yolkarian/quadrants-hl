package quadrants.linalg;

enum abstract SparseBackendKind(Int) from Int to Int {
  var HostReference = 0;
  var NativeSparse = 1;

  public inline function name():String {
    return switch (this) {
      case HostReference: "host_reference";
      case NativeSparse: "native_sparse";
      default: "unknown";
    };
  }
}
