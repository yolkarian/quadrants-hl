package quadrants.linalg;

enum abstract SparseOrdering(Int) from Int to Int {
  var AMD = 0;
  var COLAMD = 1;
  var Natural = 2;

  public inline function nativeName():String {
    return switch (this) {
      case AMD: "AMD";
      case COLAMD: "COLAMD";
      case Natural: "NATURAL";
      default: "UNKNOWN";
    };
  }
}
