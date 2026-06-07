package quadrants.linalg;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.DType;

class MatrixFreeBICGSTAB<T> {
  public final context:Context;
  public final dtype:DType;
  public final size:Int;
  public final linearOperator:LinearOperator<T>;
  final residual:Tensor<T>;
  final residualShadow:Tensor<T>;
  final direction:Tensor<T>;
  final v:Tensor<T>;
  final s:Tensor<T>;
  final t:Tensor<T>;
  final ownsResidual:Bool;
  final ownsResidualShadow:Bool;
  final ownsDirection:Bool;
  final ownsV:Bool;
  final ownsS:Bool;
  final ownsT:Bool;

  public function new(context:Context,
      dtype:DType,
      size:Int,
      linearOperator:LinearOperator<T>,
      ?residual:Tensor<T>,
      ?residualShadow:Tensor<T>,
      ?direction:Tensor<T>,
      ?v:Tensor<T>,
      ?s:Tensor<T>,
      ?t:Tensor<T>) {
    if (size <= 0) {
      throw "Quadrants matrix-free BICGSTAB size must be positive";
    }
    if (linearOperator == null) {
      throw "Quadrants matrix-free BICGSTAB operator is null";
    }
    MatrixFreeUtil.requireSupportedDType(dtype);
    this.context = context;
    this.dtype = dtype;
    this.size = size;
    this.linearOperator = linearOperator;
    ownsResidual = residual == null;
    ownsResidualShadow = residualShadow == null;
    ownsDirection = direction == null;
    ownsV = v == null;
    ownsS = s == null;
    ownsT = t == null;
    this.residual = ownsResidual ? MatrixFreeUtil.allocateTensor(context, dtype, size) : residual;
    this.residualShadow = ownsResidualShadow ? MatrixFreeUtil.allocateTensor(context, dtype, size) : residualShadow;
    this.direction = ownsDirection ? MatrixFreeUtil.allocateTensor(context, dtype, size) : direction;
    this.v = ownsV ? MatrixFreeUtil.allocateTensor(context, dtype, size) : v;
    this.s = ownsS ? MatrixFreeUtil.allocateTensor(context, dtype, size) : s;
    this.t = ownsT ? MatrixFreeUtil.allocateTensor(context, dtype, size) : t;
    MatrixFreeUtil.requireVector(context, dtype, size, this.residual, "residual");
    MatrixFreeUtil.requireVector(context, dtype, size, this.residualShadow, "residualShadow");
    MatrixFreeUtil.requireVector(context, dtype, size, this.direction, "direction");
    MatrixFreeUtil.requireVector(context, dtype, size, this.v, "v");
    MatrixFreeUtil.requireVector(context, dtype, size, this.s, "s");
    MatrixFreeUtil.requireVector(context, dtype, size, this.t, "t");
  }

  public function solve(b:Tensor<T>, x:Tensor<T>, maxIterations:Int = 128, tolerance:Float = 1.0e-5):Int {
    if (maxIterations <= 0) {
      throw "Quadrants matrix-free BICGSTAB max iterations must be positive";
    }
    if (tolerance <= 0.0) {
      throw "Quadrants matrix-free BICGSTAB tolerance must be positive";
    }
    MatrixFreeUtil.requireVector(context, dtype, size, b, "rhs");
    MatrixFreeUtil.requireVector(context, dtype, size, x, "solution");

    linearOperator.apply(x, v);
    for (i in 0...size) {
      var r = MatrixFreeUtil.toFloat(b.read(i)) - MatrixFreeUtil.toFloat(v.read(i));
      residual.write(i, MatrixFreeUtil.fromFloat(r));
      residualShadow.write(i, MatrixFreeUtil.fromFloat(r));
      direction.write(i, MatrixFreeUtil.fromFloat(0.0));
      this.v.write(i, MatrixFreeUtil.fromFloat(0.0));
    }

    var toleranceSq = tolerance * tolerance;
    if (dot(residual, residual) <= toleranceSq) {
      return 0;
    }

    var rhoOld = 1.0;
    var alpha = 1.0;
    var omega = 1.0;
    for (iteration in 1...(maxIterations + 1)) {
      var rho = dot(residualShadow, residual);
      if (Math.abs(rho) <= 1.0e-30 || Math.abs(omega) <= 1.0e-30) {
        return -iteration;
      }
      var beta = (rho / rhoOld) * (alpha / omega);
      for (i in 0...size) {
        var pi = MatrixFreeUtil.toFloat(residual.read(i)) + beta * (MatrixFreeUtil.toFloat(direction.read(i)) - omega * MatrixFreeUtil.toFloat(v.read(i)));
        direction.write(i, MatrixFreeUtil.fromFloat(pi));
      }

      linearOperator.apply(direction, v);
      var alphaDenom = dot(residualShadow, v);
      if (Math.abs(alphaDenom) <= 1.0e-30) {
        return -iteration;
      }
      alpha = rho / alphaDenom;
      for (i in 0...size) {
        var si = MatrixFreeUtil.toFloat(residual.read(i)) - alpha * MatrixFreeUtil.toFloat(v.read(i));
        s.write(i, MatrixFreeUtil.fromFloat(si));
      }
      if (dot(s, s) <= toleranceSq) {
        for (i in 0...size) {
          var xi = MatrixFreeUtil.toFloat(x.read(i)) + alpha * MatrixFreeUtil.toFloat(direction.read(i));
          x.write(i, MatrixFreeUtil.fromFloat(xi));
        }
        return iteration;
      }

      linearOperator.apply(s, t);
      var tt = dot(t, t);
      if (Math.abs(tt) <= 1.0e-30) {
        return -iteration;
      }
      omega = dot(t, s) / tt;
      for (i in 0...size) {
        var xi = MatrixFreeUtil.toFloat(x.read(i)) + alpha * MatrixFreeUtil.toFloat(direction.read(i)) + omega * MatrixFreeUtil.toFloat(s.read(i));
        var ri = MatrixFreeUtil.toFloat(s.read(i)) - omega * MatrixFreeUtil.toFloat(t.read(i));
        x.write(i, MatrixFreeUtil.fromFloat(xi));
        residual.write(i, MatrixFreeUtil.fromFloat(ri));
      }
      if (dot(residual, residual) <= toleranceSq) {
        return iteration;
      }
      rhoOld = rho;
    }
    return -maxIterations;
  }

  public function close():Void {
    if (ownsResidual) MatrixFreeUtil.closeTensor(residual);
    if (ownsResidualShadow) MatrixFreeUtil.closeTensor(residualShadow);
    if (ownsDirection) MatrixFreeUtil.closeTensor(direction);
    if (ownsV) MatrixFreeUtil.closeTensor(v);
    if (ownsS) MatrixFreeUtil.closeTensor(s);
    if (ownsT) MatrixFreeUtil.closeTensor(t);
  }

  inline function dot(lhs:Tensor<T>, rhs:Tensor<T>):Float {
    var total = 0.0;
    for (i in 0...size) {
      total += MatrixFreeUtil.toFloat(lhs.read(i)) * MatrixFreeUtil.toFloat(rhs.read(i));
    }
    return total;
  }
}
