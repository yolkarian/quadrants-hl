package quadrants;

import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.I32;

typedef SparseTriplet<T> = {
  var row:Int;
  var col:Int;
  var value:T;
}

class SparseMatrix<T> {
  public final rows:Int;
  public final cols:Int;
  final rowIndices:Array<Int> = [];
  final colIndices:Array<Int> = [];
  final values:Array<T> = [];

  public function new(rows:Int, cols:Int) {
    if (rows <= 0 || cols <= 0) {
      throw "Quadrants sparse matrix dimensions must be positive";
    }
    this.rows = rows;
    this.cols = cols;
  }

  public static function fromTriplets<T>(rows:Int, cols:Int, triplets:Array<SparseTriplet<T>>):SparseMatrix<T> {
    var matrix = new SparseMatrix<T>(rows, cols);
    for (triplet in triplets) {
      matrix.set(triplet.row, triplet.col, triplet.value);
    }
    return matrix;
  }

  public static function fromCOO<T>(ctx:Context, rowInd:Tensor<I32>, colInd:Tensor<I32>, values:Tensor<T>, nRows:Int, nCols:Int):quadrants.linalg.SparseMatrix<T> {
    requireBridgeShape("fromCOO", nRows, nCols);
    var valueRuntime = requireBridgeTensorContext("fromCOO", ctx, values);
    requireIndexTensorContext("fromCOO rowInd", ctx, rowInd);
    requireIndexTensorContext("fromCOO colInd", ctx, colInd);
    var result = new quadrants.linalg.SparseMatrix<T>(ctx, nRows, nCols, valueRuntime.dtype, quadrants.linalg.SparseStorageFormat.COO);
    var count = valueRuntime.elementCount();
    if (rowInd.elementCount() < count || colInd.elementCount() < count) {
      throw "Quadrants SparseMatrix.fromCOO index tensors are shorter than values";
    }
    for (i in 0...count) {
      result.set(rowInd.read(i), colInd.read(i), values.read(i));
    }
    return result;
  }

  public static function fromCSR<T>(ctx:Context, rowPtr:Tensor<I32>, colInd:Tensor<I32>, values:Tensor<T>, nRows:Int, nCols:Int):quadrants.linalg.SparseMatrix<T> {
    requireBridgeShape("fromCSR", nRows, nCols);
    var valueRuntime = requireBridgeTensorContext("fromCSR", ctx, values);
    requireIndexTensorContext("fromCSR rowPtr", ctx, rowPtr);
    requireIndexTensorContext("fromCSR colInd", ctx, colInd);
    if (rowPtr.elementCount() < nRows + 1) {
      throw "Quadrants SparseMatrix.fromCSR rowPtr is shorter than nRows + 1";
    }
    var result = new quadrants.linalg.SparseMatrix<T>(ctx, nRows, nCols, valueRuntime.dtype, quadrants.linalg.SparseStorageFormat.CSR);
    var nnz = values.elementCount();
    if (colInd.elementCount() < nnz) {
      throw "Quadrants SparseMatrix.fromCSR colInd tensor is shorter than values";
    }
    for (row in 0...nRows) {
      var begin = rowPtr.read(row);
      var end = rowPtr.read(row + 1);
      if (begin < 0 || end < begin || end > nnz) {
        throw "Quadrants SparseMatrix.fromCSR rowPtr contains an invalid range";
      }
      for (i in begin...end) {
        result.set(row, colInd.read(i), values.read(i));
      }
    }
    return result;
  }

  static function requireBridgeShape(operation:String, nRows:Int, nCols:Int):Void {
    if (nRows <= 0 || nCols <= 0) {
      throw 'Quadrants SparseMatrix.${operation} dimensions must be positive';
    }
  }

  static function requireBridgeTensorContext<T>(operation:String, ctx:Context, values:Tensor<T>):TensorRuntime {
    if (ctx == null) {
      throw 'Quadrants SparseMatrix.${operation} requires a Context';
    }
    if (values == null) {
      throw 'Quadrants SparseMatrix.${operation} values tensor is required';
    }
    var runtime:TensorRuntime = cast values;
    if (runtime.context != ctx) {
      throw 'Quadrants SparseMatrix.${operation} values tensor belongs to a different Context';
    }
    if (runtime.dtype != DType.F32 && runtime.dtype != DType.F64) {
      throw 'Quadrants SparseMatrix.${operation} supports only F32/F64 values';
    }
    return runtime;
  }

  static function requireIndexTensorContext(operation:String, ctx:Context, tensor:Tensor<I32>):Void {
    if (tensor == null) {
      throw 'Quadrants SparseMatrix.${operation} tensor is required';
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != ctx) {
      throw 'Quadrants SparseMatrix.${operation} tensor belongs to a different Context';
    }
    if (runtime.dtype != DType.I32) {
      throw 'Quadrants SparseMatrix.${operation} tensor must be I32';
    }
  }

  public var nnz(get, never):Int;
  inline function get_nnz():Int return values.length;

  inline function checkIndex(row:Int, col:Int):Void {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw "Quadrants sparse matrix index out of bounds";
    }
  }

  function find(row:Int, col:Int):Int {
    for (i in 0...values.length) {
      if (rowIndices[i] == row && colIndices[i] == col) {
        return i;
      }
    }
    return -1;
  }

  inline function checkSameShape(other:SparseMatrix<T>):Void {
    if (rows != other.rows || cols != other.cols) {
      throw "Quadrants sparse matrix shape mismatch";
    }
  }

  public function has(row:Int, col:Int):Bool {
    checkIndex(row, col);
    return find(row, col) >= 0;
  }

  public function get(row:Int, col:Int, defaultValue:T):T {
    checkIndex(row, col);
    var index = find(row, col);
    return index < 0 ? defaultValue : values[index];
  }

  public function set(row:Int, col:Int, value:T):Void {
    checkIndex(row, col);
    var index = find(row, col);
    if (index < 0) {
      rowIndices.push(row);
      colIndices.push(col);
      values.push(value);
    } else {
      values[index] = value;
    }
  }

  public function remove(row:Int, col:Int):Bool {
    checkIndex(row, col);
    var index = find(row, col);
    if (index < 0) {
      return false;
    }
    rowIndices.splice(index, 1);
    colIndices.splice(index, 1);
    values.splice(index, 1);
    return true;
  }

  public function clear():Void {
    rowIndices.resize(0);
    colIndices.resize(0);
    values.resize(0);
  }

  public function toTriplets():Array<SparseTriplet<T>> {
    var result = new Array<SparseTriplet<T>>();
    for (i in 0...values.length) {
      result.push({row: rowIndices[i], col: colIndices[i], value: values[i]});
    }
    return result;
  }

  public function copy():SparseMatrix<T> {
    return fromTriplets(rows, cols, toTriplets());
  }

  public function transpose():SparseMatrix<T> {
    var result = new SparseMatrix<T>(cols, rows);
    for (i in 0...values.length) {
      result.set(colIndices[i], rowIndices[i], values[i]);
    }
    return result;
  }

  public function toDense(defaultValue:T):Array<T> {
    var result = new Array<T>();
    for (_ in 0...(rows * cols)) {
      result.push(defaultValue);
    }
    for (i in 0...values.length) {
      result[rowIndices[i] * cols + colIndices[i]] = values[i];
    }
    return result;
  }


  public function add(other:SparseMatrix<T>, zero:T):SparseMatrix<T> {
    checkSameShape(other);
    var result = copy();
    for (i in 0...other.values.length) {
      var row = other.rowIndices[i];
      var col = other.colIndices[i];
      var lhs:Float = cast result.get(row, col, zero);
      var rhs:Float = cast other.values[i];
      result.set(row, col, cast (lhs + rhs));
    }
    return result;
  }

  public function sub(other:SparseMatrix<T>, zero:T):SparseMatrix<T> {
    checkSameShape(other);
    var result = copy();
    for (i in 0...other.values.length) {
      var row = other.rowIndices[i];
      var col = other.colIndices[i];
      var lhs:Float = cast result.get(row, col, zero);
      var rhs:Float = cast other.values[i];
      result.set(row, col, cast (lhs - rhs));
    }
    return result;
  }

  public function scale(value:T):SparseMatrix<T> {
    var result = new SparseMatrix<T>(rows, cols);
    for (i in 0...values.length) {
      var lhs:Float = cast values[i];
      var rhs:Float = cast value;
      result.set(rowIndices[i], colIndices[i], cast (lhs * rhs));
    }
    return result;
  }

  public function mul(other:SparseMatrix<T>, zero:T):SparseMatrix<T> {
    if (cols != other.rows) {
      throw "Quadrants sparse matrix multiplication shape mismatch";
    }
    var result = new SparseMatrix<T>(rows, other.cols);
    for (row in 0...rows) {
      for (col in 0...other.cols) {
        var total = 0.0;
        for (k in 0...cols) {
          var lhs:Float = cast get(row, k, zero);
          var rhs:Float = cast other.get(k, col, zero);
          total += lhs * rhs;
        }
        if (total != 0.0) {
          result.set(row, col, cast total);
        }
      }
    }
    return result;
  }
  public function matVec(vector:Array<T>, zero:T):Array<T> {
    if (vector.length != cols) {
      throw "Quadrants sparse matrix vector length mismatch";
    }
    var result = new Array<T>();
    for (_ in 0...rows) {
      result.push(zero);
    }
    for (i in 0...values.length) {
      var acc:Float = cast result[rowIndices[i]];
      var value:Float = cast values[i];
      var rhs:Float = cast vector[colIndices[i]];
      result[rowIndices[i]] = cast (acc + value * rhs);
    }
    return result;
  }
}
