package quadrants.linalg;

import quadrants.Context;
import quadrants.Native;
import quadrants.Native.QSparseSolver;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;

class SparseSolver<T> {
  public final context:Context;
  public final dtype:DType;
  public final solverType:SparseSolverType;
  public final ordering:SparseOrdering;
  public final allowHostDenseFallback:Bool;
  final handle:QSparseSolver;
  var closed:Bool = false;

  public function new(context:Context,
      dtype:DType = DType.F32,
      solverType:SparseSolverType = SparseSolverType.LU,
      ordering:SparseOrdering = SparseOrdering.COLAMD,
      allowHostDenseFallback:Bool = false) {
    if (!SparseBackendFeatures.probe(context).supportsDType(dtype)) {
      throw "Quadrants sparse solver bridge supports only F32 and F64";
    }
    this.context = context;
    this.dtype = dtype;
    this.solverType = solverType;
    this.ordering = ordering;
    this.allowHostDenseFallback = allowHostDenseFallback;
    var solverBytes = @:privateAccess solverType.nativeName().toUtf8();
    var orderingBytes = @:privateAccess ordering.nativeName().toUtf8();
    handle = Native.sparse_solver_create(context.nativeHandle(), dtype, solverBytes, orderingBytes, allowHostDenseFallback ? 1 : 0);
  }

  public function nativeHandle():QSparseSolver {
    if (closed) {
      throw "Quadrants sparse solver is closed";
    }
    return handle;
  }

  public function compute(matrix:SparseMatrix<T>):Bool {
    requireMatrix(matrix);
    return Native.sparse_solver_compute(context.nativeHandle(), nativeHandle(), matrix.nativeHandle()) != 0;
  }

  public function info():Bool {
    return Native.sparse_solver_info(context.nativeHandle(), nativeHandle()) != 0;
  }

  public function solve(matrix:SparseMatrix<T>, b:Tensor<T>, x:Tensor<T>):Void {
    requireMatrix(matrix);
    requireTensorContext(b, matrix.rows, "rhs");
    requireTensorContext(x, matrix.cols, "solution");
    switch (dtype) {
      case DType.F32:
        Native.sparse_solver_solve_f32(context.nativeHandle(), nativeHandle(), matrix.nativeHandle(), (cast b : TensorRuntime).nativeHandle(), (cast x : TensorRuntime).nativeHandle());
      case DType.F64:
        Native.sparse_solver_solve_f64(context.nativeHandle(), nativeHandle(), matrix.nativeHandle(), (cast b : TensorRuntime).nativeHandle(), (cast x : TensorRuntime).nativeHandle());
      default:
        throw "Quadrants sparse solver solve supports only F32 and F64";
    }
  }

  public function close():Void {
    if (!closed) {
      Native.sparse_solver_close(handle);
      closed = true;
    }
  }

  function requireMatrix(matrix:SparseMatrix<T>):Void {
    if (matrix.context != context) {
      throw "Quadrants sparse solver matrix belongs to a different context";
    }
    if (matrix.dtype != dtype) {
      throw "Quadrants sparse solver matrix dtype mismatch";
    }
  }

  function requireTensorContext(tensor:Tensor<T>, minElements:Int, name:String):TensorRuntime {
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != context) {
      throw 'Quadrants sparse solver ${name} tensor belongs to a different context';
    }
    if (runtime.dtype != dtype) {
      throw 'Quadrants sparse solver ${name} tensor dtype mismatch';
    }
    if (runtime.elementCount() < minElements) {
      throw 'Quadrants sparse solver ${name} tensor is too small';
    }
    return runtime;
  }
}