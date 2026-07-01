package quadrants.linalg;

import quadrants.Context;
import quadrants.Native;
import quadrants.Native.QSparseMatrix;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.I32;

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
    if (context == null) {
      throw "Quadrants sparse matrix requires a Context";
    }
    if (rows <= 0 || cols <= 0) {
      throw "Quadrants sparse matrix dimensions must be positive";
    }
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

  public static function fromCOO<T>(ctx:Context, rowInd:Tensor<I32>, colInd:Tensor<I32>, values:Tensor<T>, nRows:Int, nCols:Int):SparseMatrix<T> {
    requireShape("fromCOO", nRows, nCols);
    var valueRuntime = requireValueTensor("fromCOO values", ctx, values);
    var rowRuntime = requireIndexTensor("fromCOO rowInd", ctx, rowInd, valueRuntime.elementCount());
    var colRuntime = requireIndexTensor("fromCOO colInd", ctx, colInd, valueRuntime.elementCount());
    var result = new SparseMatrix<T>(ctx, nRows, nCols, valueRuntime.dtype, SparseStorageFormat.COO);
    switch (valueRuntime.dtype) {
      case DType.F32:
        Native.sparse_matrix_load_coo_f32(ctx.nativeHandle(), result.nativeHandle(), rowRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      case DType.F64:
        Native.sparse_matrix_load_coo_f64(ctx.nativeHandle(), result.nativeHandle(), rowRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      default:
        throw "Quadrants SparseMatrix.fromCOO supports only F32/F64 values";
    }
    return result;
  }

  public static function fromCSR<T>(ctx:Context, rowPtr:Tensor<I32>, colInd:Tensor<I32>, values:Tensor<T>, nRows:Int, nCols:Int):SparseMatrix<T> {
    requireShape("fromCSR", nRows, nCols);
    var valueRuntime = requireValueTensor("fromCSR values", ctx, values);
    var rowPtrRuntime = requireIndexTensor("fromCSR rowPtr", ctx, rowPtr, nRows + 1);
    var colRuntime = requireIndexTensor("fromCSR colInd", ctx, colInd, valueRuntime.elementCount());
    var result = new SparseMatrix<T>(ctx, nRows, nCols, valueRuntime.dtype, SparseStorageFormat.CSR);
    switch (valueRuntime.dtype) {
      case DType.F32:
        Native.sparse_matrix_load_csr_f32(ctx.nativeHandle(), result.nativeHandle(), rowPtrRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      case DType.F64:
        Native.sparse_matrix_load_csr_f64(ctx.nativeHandle(), result.nativeHandle(), rowPtrRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      default:
        throw "Quadrants SparseMatrix.fromCSR supports only F32/F64 values";
    }
    return result;
  }

  public static function mmread<T>(ctx:Context,
      path:String,
      dtype:DType = DType.F32,
      storageFormat:SparseStorageFormat = SparseStorageFormat.CSR):SparseMatrix<T> {
    if (path == null || path.length == 0) {
      throw "Quadrants sparse mmread requires a path";
    }
    if (dtype != DType.F32 && dtype != DType.F64) {
      throw "Quadrants sparse mmread supports only F32 and F64";
    }
    var lines = sys.io.File.getContent(path).split("\n");
    var headerSeen = false;
    var result:SparseMatrix<T> = null;
    var expectedEntries = -1;
    var actualEntries = 0;
    for (line in lines) {
      var trimmed = StringTools.trim(line);
      if (trimmed.length == 0) {
        continue;
      }
      if (!headerSeen) {
        var header = splitWords(trimmed);
        if (header.length < 5 || header[0] != "%%MatrixMarket") {
          throw "Quadrants sparse mmread requires a MatrixMarket coordinate header";
        }
        var object = header[1].toLowerCase();
        var format = header[2].toLowerCase();
        var field = header[3].toLowerCase();
        var symmetry = header[4].toLowerCase();
        if (object != "matrix" || format != "coordinate" || (field != "real" && field != "integer") || symmetry != "general") {
          throw "Quadrants sparse mmread supports only MatrixMarket matrix coordinate real/integer general";
        }
        headerSeen = true;
        continue;
      }
      if (StringTools.startsWith(trimmed, "%")) {
        continue;
      }
      var parts = splitWords(trimmed);
      if (result == null) {
        if (parts.length != 3) {
          throw "Quadrants sparse mmread size line must contain rows, cols, and entries";
        }
        var nRows = parsePositiveInt(parts[0], "rows");
        var nCols = parsePositiveInt(parts[1], "cols");
        expectedEntries = parseNonNegativeInt(parts[2], "entries");
        result = new SparseMatrix<T>(ctx, nRows, nCols, dtype, storageFormat);
        continue;
      }
      if (parts.length != 3) {
        throw "Quadrants sparse mmread entry line must contain row, col, and value";
      }
      var row = parsePositiveInt(parts[0], "row") - 1;
      var col = parsePositiveInt(parts[1], "col") - 1;
      var value = Std.parseFloat(parts[2]);
      if (Math.isNaN(value)) {
        throw "Quadrants sparse mmread entry value is not a number";
      }
      result.checkBounds(row, col, "mmread");
      result.setFloat(row, col, value);
      actualEntries++;
    }
    if (!headerSeen || result == null) {
      throw "Quadrants sparse mmread file is incomplete";
    }
    if (actualEntries != expectedEntries) {
      throw "Quadrants sparse mmread entry count mismatch";
    }
    return result;
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

  public function toCOO(rowInd:Tensor<I32>, colInd:Tensor<I32>, values:Tensor<T>):Int {
    var rowRuntime = requireIndexTensor("toCOO rowInd", context, rowInd, nnz);
    var colRuntime = requireIndexTensor("toCOO colInd", context, colInd, nnz);
    var valueRuntime = requireTensorContext(values, nnz, "toCOO values");
    return switch (dtype) {
      case DType.F32:
        Native.sparse_matrix_to_coo_f32(context.nativeHandle(), nativeHandle(), rowRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      case DType.F64:
        Native.sparse_matrix_to_coo_f64(context.nativeHandle(), nativeHandle(), rowRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      default:
        throw "Quadrants sparse matrix toCOO supports only F32 and F64";
    };
  }

  public function toCSR(rowPtr:Tensor<I32>, colInd:Tensor<I32>, values:Tensor<T>):Int {
    var rowRuntime = requireIndexTensor("toCSR rowPtr", context, rowPtr, rows + 1);
    var colRuntime = requireIndexTensor("toCSR colInd", context, colInd, nnz);
    var valueRuntime = requireTensorContext(values, nnz, "toCSR values");
    return switch (dtype) {
      case DType.F32:
        Native.sparse_matrix_to_csr_f32(context.nativeHandle(), nativeHandle(), rowRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      case DType.F64:
        Native.sparse_matrix_to_csr_f64(context.nativeHandle(), nativeHandle(), rowRuntime.nativeHandle(), colRuntime.nativeHandle(), valueRuntime.nativeHandle());
      default:
        throw "Quadrants sparse matrix toCSR supports only F32 and F64";
    };
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

  function checkBounds(row:Int, col:Int, operation:String):Void {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw 'Quadrants SparseMatrix.${operation} index out of bounds';
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

  static function requireShape(operation:String, nRows:Int, nCols:Int):Void {
    if (nRows <= 0 || nCols <= 0) {
      throw 'Quadrants SparseMatrix.${operation} dimensions must be positive';
    }
  }

  static function splitWords(line:String):Array<String> {
    var result = new Array<String>();
    var current = new StringBuf();
    var trimmed = StringTools.trim(line);
    for (i in 0...trimmed.length) {
      var ch = trimmed.charAt(i);
      if (ch == " " || ch == "\t" || ch == "\r") {
        if (current.length > 0) {
          result.push(current.toString());
          current = new StringBuf();
        }
      } else {
        current.add(ch);
      }
    }
    if (current.length > 0) {
      result.push(current.toString());
    }
    return result;
  }

  static function parsePositiveInt(value:String, name:String):Int {
    var parsed = Std.parseInt(value);
    if (parsed == null || parsed <= 0) {
      throw 'Quadrants sparse mmread ${name} must be positive';
    }
    return parsed;
  }

  static function parseNonNegativeInt(value:String, name:String):Int {
    var parsed = Std.parseInt(value);
    if (parsed == null || parsed < 0) {
      throw 'Quadrants sparse mmread ${name} must be non-negative';
    }
    return parsed;
  }

  static function requireValueTensor<T>(name:String, ctx:Context, tensor:Tensor<T>):TensorRuntime {
    if (ctx == null) {
      throw 'Quadrants sparse matrix ${name} requires a Context';
    }
    if (tensor == null) {
      throw 'Quadrants sparse matrix ${name} tensor is required';
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != ctx) {
      throw 'Quadrants sparse matrix ${name} tensor belongs to a different context';
    }
    if (runtime.dtype != DType.F32 && runtime.dtype != DType.F64) {
      throw 'Quadrants sparse matrix ${name} supports only F32/F64 values';
    }
    return runtime;
  }

  static function requireIndexTensor(name:String, ctx:Context, tensor:Tensor<I32>, minElements:Int):TensorRuntime {
    if (tensor == null) {
      throw 'Quadrants sparse matrix ${name} tensor is required';
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != ctx) {
      throw 'Quadrants sparse matrix ${name} tensor belongs to a different context';
    }
    if (runtime.dtype != DType.I32) {
      throw 'Quadrants sparse matrix ${name} tensor must be I32';
    }
    if (runtime.elementCount() < minElements) {
      throw 'Quadrants sparse matrix ${name} tensor is too small';
    }
    return runtime;
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
