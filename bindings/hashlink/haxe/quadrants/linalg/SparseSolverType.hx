package quadrants.linalg;

enum abstract SparseSolverType(Int) from Int to Int {
  var LLT = 0;
  var LDLT = 1;
  var LU = 2;

  public inline function nativeName():String {
    return switch (this) {
      case LLT: "LLT";
      case LDLT: "LDLT";
      case LU: "LU";
      default: "UNKNOWN";
    };
  }
}
