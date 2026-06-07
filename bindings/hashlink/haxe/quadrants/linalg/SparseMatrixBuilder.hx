package quadrants.linalg;

import quadrants.Context;
import quadrants.Types.DType;

class SparseMatrixBuilder<T> {
  public final context:Context;
  public final rows:Int;
  public final cols:Int;
  public final dtype:DType;
  public final storageFormat:SparseStorageFormat;
  public final maxNumTriplets:Int;
  final matrix:SparseMatrix<T>;
  var built:Bool = false;

  public function new(context:Context,
      rows:Int,
      cols:Int,
      dtype:DType = DType.F32,
      storageFormat:SparseStorageFormat = SparseStorageFormat.CSR,
      maxNumTriplets:Int = -1) {
    if (maxNumTriplets < -1) {
      throw "Quadrants sparse matrix builder maxNumTriplets must be non-negative or -1";
    }
    this.context = context;
    this.rows = rows;
    this.cols = cols;
    this.dtype = dtype;
    this.storageFormat = storageFormat;
    this.maxNumTriplets = maxNumTriplets;
    matrix = new SparseMatrix<T>(context, rows, cols, dtype, storageFormat);
  }

  public function add(row:Int, col:Int, value:T):SparseMatrixBuilder<T> {
    ensureOpen();
    var current = MatrixFreeUtil.toFloat(matrix.get(row, col));
    var next = current + MatrixFreeUtil.toFloat(value);
    if (next != 0.0) {
      reserveTriplet(row, col);
    }
    matrix.set(row, col, MatrixFreeUtil.fromFloat(next));
    return this;
  }

  public function set(row:Int, col:Int, value:T):SparseMatrixBuilder<T> {
    ensureOpen();
    if (MatrixFreeUtil.toFloat(value) != 0.0) {
      reserveTriplet(row, col);
    }
    matrix.set(row, col, value);
    return this;
  }

  public function clear():Void {
    ensureOpen();
    matrix.clear();
  }

  public function build():SparseMatrix<T> {
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

  function reserveTriplet(row:Int, col:Int):Void {
    if (maxNumTriplets >= 0 && !matrix.has(row, col) && matrix.nnz >= maxNumTriplets) {
      throw "Quadrants sparse matrix builder maxNumTriplets exceeded";
    }
  }

  function ensureOpen():Void {
    if (built) {
      throw "Quadrants sparse matrix builder is already built";
    }
  }
}
