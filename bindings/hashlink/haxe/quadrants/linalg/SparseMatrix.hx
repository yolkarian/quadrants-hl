package quadrants.linalg;

import quadrants.Context;
import quadrants.Native;
import quadrants.Native.QSparseMatrix;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;

class SparseMatrix {
  public final context:Context;
  public final rows:Int;
  public final cols:Int;
  public final dtype:DType;
  final handle:QSparseMatrix;
  var closed:Bool = false;

  public function new(context:Context, rows:Int, cols:Int, dtype:DType = DType.F32) {
    this.context = context;
    this.rows = rows;
    this.cols = cols;
    this.dtype = dtype;
    handle = Native.sparse_matrix_create(context.nativeHandle(), rows, cols, dtype);
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

  public function set(row:Int, col:Int, value:F32):Void {
    Native.sparse_matrix_set_f32(context.nativeHandle(), nativeHandle(), row, col, value);
  }

  public function get(row:Int, col:Int):F32 {
    return cast Native.sparse_matrix_get_f32(context.nativeHandle(), nativeHandle(), row, col);
  }

  public function toDense():Array<F32> {
    return [for (row in 0...rows) for (col in 0...cols) get(row, col)];
  }

  public function matVec(x:Tensor<F32>, y:Tensor<F32>):Void {
    requireTensorContext(x, "input");
    requireTensorContext(y, "output");
    Native.sparse_matrix_matvec_f32(context.nativeHandle(), nativeHandle(), x.nativeHandle(), y.nativeHandle());
  }

  public function close():Void {
    if (!closed) {
      Native.sparse_matrix_close(handle);
      closed = true;
    }
  }

  function requireTensorContext(tensor:Dynamic, name:String):TensorRuntime {
    if (!Std.isOfType(tensor, TensorRuntime)) {
      throw 'Quadrants sparse matrix ${name} must be a Tensor';
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != context) {
      throw 'Quadrants sparse matrix ${name} tensor belongs to a different context';
    }
    return runtime;
  }
}
