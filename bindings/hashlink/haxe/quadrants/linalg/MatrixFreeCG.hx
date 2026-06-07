package quadrants.linalg;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.DType;

class MatrixFreeCG<T> {
  public final context:Context;
  public final dtype:DType;
  public final size:Int;
  public final linearOperator:LinearOperator<T>;
  final residual:Tensor<T>;
  final direction:Tensor<T>;
  final work:Tensor<T>;
  final ownsResidual:Bool;
  final ownsDirection:Bool;
  final ownsWork:Bool;

  public function new(context:Context,
      dtype:DType,
      size:Int,
      linearOperator:LinearOperator<T>,
      ?residual:Tensor<T>,
      ?direction:Tensor<T>,
      ?work:Tensor<T>) {
    if (size <= 0) {
      throw "Quadrants matrix-free CG size must be positive";
    }
    if (linearOperator == null) {
      throw "Quadrants matrix-free CG operator is null";
    }
    MatrixFreeUtil.requireSupportedDType(dtype);
    this.context = context;
    this.dtype = dtype;
    this.size = size;
    this.linearOperator = linearOperator;
    ownsResidual = residual == null;
    ownsDirection = direction == null;
    ownsWork = work == null;
    this.residual = ownsResidual ? MatrixFreeUtil.allocateTensor(context, dtype, size) : residual;
    this.direction = ownsDirection ? MatrixFreeUtil.allocateTensor(context, dtype, size) : direction;
    this.work = ownsWork ? MatrixFreeUtil.allocateTensor(context, dtype, size) : work;
    MatrixFreeUtil.requireVector(context, dtype, size, this.residual, "residual");
    MatrixFreeUtil.requireVector(context, dtype, size, this.direction, "direction");
    MatrixFreeUtil.requireVector(context, dtype, size, this.work, "work");
  }

  public function solve(b:Tensor<T>, x:Tensor<T>, maxIterations:Int = 128, tolerance:Float = 1.0e-5):Int {
    if (maxIterations <= 0) {
      throw "Quadrants matrix-free CG max iterations must be positive";
    }
    if (tolerance <= 0.0) {
      throw "Quadrants matrix-free CG tolerance must be positive";
    }
    MatrixFreeUtil.requireVector(context, dtype, size, b, "rhs");
    MatrixFreeUtil.requireVector(context, dtype, size, x, "solution");

    linearOperator.apply(x, work);
    for (i in 0...size) {
      var r = MatrixFreeUtil.toFloat(b.read(i)) - MatrixFreeUtil.toFloat(work.read(i));
      residual.write(i, MatrixFreeUtil.fromFloat(r));
      direction.write(i, MatrixFreeUtil.fromFloat(r));
    }

    var residualSq = dot(residual, residual);
    var toleranceSq = tolerance * tolerance;
    if (residualSq <= toleranceSq) {
      return 0;
    }

    for (iteration in 1...(maxIterations + 1)) {
      linearOperator.apply(direction, work);
      var denom = dot(direction, work);
      if (Math.abs(denom) <= 1.0e-30) {
        return -iteration;
      }
      var alpha = residualSq / denom;
      for (i in 0...size) {
        var xi = MatrixFreeUtil.toFloat(x.read(i)) + alpha * MatrixFreeUtil.toFloat(direction.read(i));
        var ri = MatrixFreeUtil.toFloat(residual.read(i)) - alpha * MatrixFreeUtil.toFloat(work.read(i));
        x.write(i, MatrixFreeUtil.fromFloat(xi));
        residual.write(i, MatrixFreeUtil.fromFloat(ri));
      }
      var nextResidualSq = dot(residual, residual);
      if (nextResidualSq <= toleranceSq) {
        return iteration;
      }
      var beta = nextResidualSq / residualSq;
      for (i in 0...size) {
        var pi = MatrixFreeUtil.toFloat(residual.read(i)) + beta * MatrixFreeUtil.toFloat(direction.read(i));
        direction.write(i, MatrixFreeUtil.fromFloat(pi));
      }
      residualSq = nextResidualSq;
    }
    return -maxIterations;
  }

  public function close():Void {
    if (ownsResidual) MatrixFreeUtil.closeTensor(residual);
    if (ownsDirection) MatrixFreeUtil.closeTensor(direction);
    if (ownsWork) MatrixFreeUtil.closeTensor(work);
  }

  inline function dot(lhs:Tensor<T>, rhs:Tensor<T>):Float {
    var total = 0.0;
    for (i in 0...size) {
      total += MatrixFreeUtil.toFloat(lhs.read(i)) * MatrixFreeUtil.toFloat(rhs.read(i));
    }
    return total;
  }
}
