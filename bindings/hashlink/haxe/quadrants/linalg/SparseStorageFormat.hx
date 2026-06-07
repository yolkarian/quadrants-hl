package quadrants.linalg;

enum abstract SparseStorageFormat(Int) from Int to Int {
  var CSR = 0;
  var COO = 1;

  public inline function name():String {
    return switch (this) {
      case CSR: "CSR";
      case COO: "COO";
      default: "UNKNOWN";
    };
  }
}
