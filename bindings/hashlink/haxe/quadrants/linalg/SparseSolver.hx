package quadrants.linalg;

import quadrants.Context;
import quadrants.Native;
import quadrants.Native.QSparseSolver;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;

class SparseSolver {
  public final context:Context;
  public final dtype:DType;
  final handle:QSparseSolver;
  var closed:Bool = false;

  public function new(context:Context, dtype:DType = DType.F32, solverType:String = "LU", ordering:String = "COLAMD") {
    this.context = context;
    this.dtype = dtype;
    var solverBytes = @:privateAccess solverType.toUtf8();
    var orderingBytes = @:privateAccess ordering.toUtf8();
    handle = Native.sparse_solver_create(context.nativeHandle(), dtype, solverBytes, orderingBytes);
  }

  public function nativeHandle():QSparseSolver {
    if (closed) {
      throw "Quadrants sparse solver is closed";
    }
    return handle;
  }

  public function compute(matrix:SparseMatrix):Bool {
    requireMatrix(matrix);
    return Native.sparse_solver_compute(context.nativeHandle(), nativeHandle(), matrix.nativeHandle()) != 0;
  }

  public function info():Bool {
    return Native.sparse_solver_info(context.nativeHandle(), nativeHandle()) != 0;
  }

  public function solve(matrix:SparseMatrix, b:Tensor<F32>, x:Tensor<F32>):Void {
    requireMatrix(matrix);
    requireTensorContext(b, "rhs");
    requireTensorContext(x, "solution");
    Native.sparse_solver_solve_f32(context.nativeHandle(), nativeHandle(), matrix.nativeHandle(), b.nativeHandle(), x.nativeHandle());
  }

  public function close():Void {
    if (!closed) {
      Native.sparse_solver_close(handle);
      closed = true;
    }
  }

  function requireMatrix(matrix:SparseMatrix):Void {
    if (matrix.context != context) {
      throw "Quadrants sparse solver matrix belongs to a different context";
    }
  }

  function requireTensorContext(tensor:Dynamic, name:String):TensorRuntime {
    if (!Std.isOfType(tensor, TensorRuntime)) {
      throw 'Quadrants sparse solver ${name} must be a Tensor';
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != context) {
      throw 'Quadrants sparse solver ${name} tensor belongs to a different context';
    }
    return runtime;
  }
}
