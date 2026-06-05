package quadrants.linalg;

import quadrants.Context;
import quadrants.Types.DType;
import quadrants.Types.F32;

class SparseMatrixBuilder {
  public final context:Context;
  public final rows:Int;
  public final cols:Int;
  public final dtype:DType;
  final matrix:SparseMatrix;
  var built:Bool = false;

  public function new(context:Context, rows:Int, cols:Int, dtype:DType = DType.F32) {
    this.context = context;
    this.rows = rows;
    this.cols = cols;
    this.dtype = dtype;
    matrix = new SparseMatrix(context, rows, cols, dtype);
  }

  public function add(row:Int, col:Int, value:F32):SparseMatrixBuilder {
    ensureOpen();
    var current:F32 = matrix.get(row, col);
    matrix.set(row, col, cast ((current : Float) + (value : Float)));
    return this;
  }

  public function set(row:Int, col:Int, value:F32):SparseMatrixBuilder {
    ensureOpen();
    matrix.set(row, col, value);
    return this;
  }

  public function clear():Void {
    ensureOpen();
    matrix.clear();
  }

  public function build():SparseMatrix {
    ensureOpen();
    built = true;
    return matrix;
  }

  public function close():Void {
    if (!built) {
      matrix.close();
      built = true;
    }
  }

  function ensureOpen():Void {
    if (built) {
      throw "Quadrants sparse matrix builder is already built";
    }
  }
}
