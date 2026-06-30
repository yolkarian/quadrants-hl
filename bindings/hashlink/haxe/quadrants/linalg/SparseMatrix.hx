package quadrants.linalg;

import quadrants.Context;
import quadrants.Native;
import quadrants.Native.QSparseMatrix;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;

class SparseMatrix<T> implements LinearOperator<T> {
  public final context:Context;
  public final rows:Int;
  public final cols:Int;
  public final dtype:DType;
  public final storageFormat:SparseStorageFormat;
  final handle:QSparseMatrix;
  var closed:Bool = false;

  public function new(context:Context,
      rows:Int,
      cols:Int,
      dtype:DType = DType.F32,
      storageFormat:SparseStorageFormat = SparseStorageFormat.CSR) {
    if (!SparseBackendFeatures.probe(context).supportsDType(dtype)) {
      throw "Quadrants sparse matrix bridge supports only F32 and F64";
    }
    this.context = context;
    this.rows = rows;
    this.cols = cols;
    this.dtype = dtype;
    this.storageFormat = storageFormat;
    handle = Native.sparse_matrix_create(context.nativeHandle(), rows, cols, dtype, storageFormat);
  }

  public function nativeHandle():QSparseMatrix {
    if (closed) {
      throw "Quadrants sparse matrix is closed";
    }
    return handle;
  }

  public var nnz(get, never):Int;
  function get_nnz():Int {
    return Native.sparse_matrix_nnz(context.nativeHandle(), nativeHandle());
  }

  public function clear():Void {
    Native.sparse_matrix_clear(context.nativeHandle(), nativeHandle());
  }

  public function has(row:Int, col:Int):Bool {
    return getFloat(row, col) != 0.0;
  }

  public function set(row:Int, col:Int, value:T):Void {
    setFloat(row, col, toFloat(value));
  }

  public function get(row:Int, col:Int):T {
    return fromFloat(getFloat(row, col));
  }

  public function toDense():Array<Float> {
    var result = new Array<Float>();
    for (row in 0...rows) {
      for (col in 0...cols) {
        result.push(getFloat(row, col));
      }
    }
    return result;
  }

  public function copy():SparseMatrix<T> {
    var result = new SparseMatrix<T>(context, rows, cols, dtype, storageFormat);
    for (row in 0...rows) {
      for (col in 0...cols) {
        var value = getFloat(row, col);
        if (value != 0.0) {
          result.setFloat(row, col, value);
        }
      }
    }
    return result;
  }

  public function transpose():SparseMatrix<T> {
    var result = new SparseMatrix<T>(context, cols, rows, dtype, storageFormat);
    for (row in 0...rows) {
      for (col in 0...cols) {
        var value = getFloat(row, col);
        if (value != 0.0) {
          result.setFloat(col, row, value);
        }
      }
    }
    return result;
  }

  public function add(other:SparseMatrix<T>):SparseMatrix<T> {
    checkSameShape(other);
    var result = new SparseMatrix<T>(context, rows, cols, dtype, storageFormat);
    for (row in 0...rows) {
      for (col in 0...cols) {
        var value = getFloat(row, col) + other.getFloat(row, col);
        if (value != 0.0) {
          result.setFloat(row, col, value);
        }
      }
    }
    return result;
  }

  public function sub(other:SparseMatrix<T>):SparseMatrix<T> {
    checkSameShape(other);
    var result = new SparseMatrix<T>(context, rows, cols, dtype, storageFormat);
    for (row in 0...rows) {
      for (col in 0...cols) {
        var value = getFloat(row, col) - other.getFloat(row, col);
        if (value != 0.0) {
          result.setFloat(row, col, value);
        }
      }
    }
    return result;
  }

  public function mul(other:SparseMatrix<T>):SparseMatrix<T> {
    if (cols != other.rows) {
      throw "Quadrants sparse matrix multiplication shape mismatch";
    }
    requireCompatible(other);
    var result = new SparseMatrix<T>(context, rows, other.cols, dtype, storageFormat);
    for (row in 0...rows) {
      for (col in 0...other.cols) {
        var total = 0.0;
        for (k in 0...cols) {
          total += getFloat(row, k) * other.getFloat(k, col);
        }
        if (total != 0.0) {
          result.setFloat(row, col, total);
        }
      }
    }
    return result;
  }

  public function scale(value:T):SparseMatrix<T> {
    var factor = toFloat(value);
    var result = new SparseMatrix<T>(context, rows, cols, dtype, storageFormat);
    if (factor == 0.0) {
      return result;
    }
    for (row in 0...rows) {
      for (col in 0...cols) {
        var scaled = getFloat(row, col) * factor;
        if (scaled != 0.0) {
          result.setFloat(row, col, scaled);
        }
      }
    }
    return result;
  }

  public function matVec(x:Tensor<T>, y:Tensor<T>):Void {
    requireTensorContext(x, cols, "input");
    requireTensorContext(y, rows, "output");
    switch (dtype) {
      case DType.F32:
        Native.sparse_matrix_matvec_f32(context.nativeHandle(), nativeHandle(), (cast x : TensorRuntime).nativeHandle(), (cast y : TensorRuntime).nativeHandle());
      case DType.F64:
        Native.sparse_matrix_matvec_f64(context.nativeHandle(), nativeHandle(), (cast x : TensorRuntime).nativeHandle(), (cast y : TensorRuntime).nativeHandle());
      default:
        throw "Quadrants sparse matrix matVec supports only F32 and F64";
    }
  }

  public inline function matvec(x:Tensor<T>, y:Tensor<T>):Void {
    matVec(x, y);
  }

  public inline function apply(x:Tensor<T>, y:Tensor<T>):Void {
    matVec(x, y);
  }

  public function buildFromTensor(dense:Tensor<T>, ?options:{?eps:Float}):Void {
    var runtime:TensorRuntime = requireTensorContext(dense, rows * cols, "dense source");
    if (runtime.shape.length != 2 || runtime.shape[0] != rows || runtime.shape[1] != cols) {
      throw "Quadrants sparse buildFromTensor source shape mismatch";
    }
    var eps = options == null || options.eps == null ? 0.0 : options.eps;
    clear();
    for (row in 0...rows) {
      for (col in 0...cols) {
        var value:T = dense.read(row * cols + col);
        var asFloat = toFloat(value);
        if (Math.abs(asFloat) > eps) {
          set(row, col, value);
        }
      }
    }
  }

  public function mmwrite(path:String):Void {
    if (path == null || path.length == 0) {
      throw "Quadrants sparse mmwrite requires a path";
    }
    var entries = new Array<{row:Int, col:Int, value:Float}>();
    for (row in 0...rows) {
      for (col in 0...cols) {
        var value = getFloat(row, col);
        if (value != 0.0) {
          entries.push({row: row, col: col, value: value});
        }
      }
    }
    var out = new StringBuf();
    out.add("%%MatrixMarket matrix coordinate real general\n");
    out.add("% written by quadrants HashLink sparse bridge\n");
    out.add('${rows} ${cols} ${entries.length}\n');
    for (entry in entries) {
      out.add('${entry.row + 1} ${entry.col + 1} ${entry.value}\n');
    }
    sys.io.File.saveContent(path, out.toString());
  }

  public function close():Void {
    if (!closed) {
      Native.sparse_matrix_close(handle);
      closed = true;
    }
  }

  inline function toFloat(value:T):Float {
    return cast value;
  }

  inline function fromFloat(value:Float):T {
    return cast value;
  }

  function getFloat(row:Int, col:Int):Float {
    return switch (dtype) {
      case DType.F32:
        Native.sparse_matrix_get_f32(context.nativeHandle(), nativeHandle(), row, col);
      case DType.F64:
        Native.sparse_matrix_get_f64(context.nativeHandle(), nativeHandle(), row, col);
      default:
        throw "Quadrants sparse matrix get supports only F32 and F64";
    };
  }

  function setFloat(row:Int, col:Int, value:Float):Void {
    switch (dtype) {
      case DType.F32:
        Native.sparse_matrix_set_f32(context.nativeHandle(), nativeHandle(), row, col, value);
      case DType.F64:
        Native.sparse_matrix_set_f64(context.nativeHandle(), nativeHandle(), row, col, value);
      default:
        throw "Quadrants sparse matrix set supports only F32 and F64";
    }
  }

  function checkSameShape(other:SparseMatrix<T>):Void {
    requireCompatible(other);
    if (rows != other.rows || cols != other.cols) {
      throw "Quadrants sparse matrix shape mismatch";
    }
  }

  function requireCompatible(other:SparseMatrix<T>):Void {
    if (other.context != context) {
      throw "Quadrants sparse matrix belongs to a different context";
    }
    if (other.dtype != dtype) {
      throw "Quadrants sparse matrix dtype mismatch";
    }
  }

  function requireTensorContext(tensor:Tensor<T>, minElements:Int, name:String):TensorRuntime {
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != context) {
      throw 'Quadrants sparse matrix ${name} tensor belongs to a different context';
    }
    if (runtime.dtype != dtype) {
      throw 'Quadrants sparse matrix ${name} tensor dtype mismatch';
    }
    if (runtime.elementCount() < minElements) {
      throw 'Quadrants sparse matrix ${name} tensor is too small';
    }
    return runtime;
  }
}
