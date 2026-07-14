package quadrants.math;

import quadrants.Matrix;
import quadrants.Vector;
import quadrants.Types.F64;

/** Kernel-local GLSL-style helpers for explicit F64 values. */
class MathF64 {
  @:qdFunc
  public static function mixF64(x:F64, y:F64, a:F64):F64 {
    return ((x : Float) * (1.0 - (a : Float)) + (y : Float) * (a : Float));
  }

  @:qdFunc
  public static function clampF64(x:F64, xmin:F64, xmax:F64):F64 {
    return (Math.min((xmax : Float), Math.max((xmin : Float), (x : Float))));
  }

  @:qdFunc
  public static function stepF64(edge:F64, x:F64):F64 {
    return MathF64Builtin.select(
      (x : Float) < (edge : Float),
      (x : Float) - (x : Float),
      (x : Float) - (x : Float) + 1.0);
  }

  @:qdFunc
  public static function fractF64(x:F64):F64 {
    return ((x : Float) - Math.floor((x : Float)));
  }

  @:qdFunc
  public static function smoothstepF64(edge0:F64, edge1:F64, x:F64):F64 {
    return ((clampF64((((x : Float) - (edge0 : Float)) / ((edge1 : Float) - (edge0 : Float))), 0.0, 1.0) : Float)
      * (clampF64((((x : Float) - (edge0 : Float)) / ((edge1 : Float) - (edge0 : Float))), 0.0, 1.0) : Float)
      * (3.0 - 2.0 * (clampF64((((x : Float) - (edge0 : Float)) / ((edge1 : Float) - (edge0 : Float))), 0.0, 1.0) : Float)));
  }

  @:qdFunc
  public static function signF64(x:F64):F64 {
    return MathF64Builtin.select(
      (x : Float) < 0.0,
      (x : Float) - (x : Float) - 1.0,
      MathF64Builtin.select(
        (x : Float) > 0.0,
        (x : Float) - (x : Float) + 1.0,
        (x : Float) - (x : Float)));
  }

  @:qdFunc
  public static function log2F64(x:F64):F64 {
    return (Math.log((x : Float)) / Math.log(2.0));
  }

  @:qdFunc
  public static function degreesF64(x:F64):F64 {
    return ((x : Float) * 57.295779513082320876798154814105);
  }

  @:qdFunc
  public static function radiansF64(x:F64):F64 {
    return ((x : Float) * 0.017453292519943295769236907684886);
  }

  @:qdFunc
  public static function modF64(x:F64, y:F64):F64 {
    return ((x : Float) - (y : Float) * Math.floor((x : Float) / (y : Float)));
  }

  @:qdFunc
  public static function isinfF64(x:F64):Bool {
    return (x : Float) == (x : Float) && ((x : Float) - (x : Float)) != ((x : Float) - (x : Float));
  }

  @:qdFunc
  public static function isnanF64(x:F64):Bool {
    return (x : Float) != (x : Float);
  }

  @:qdFunc
  public static function dot2F64(x:Vector<F64>, y:Vector<F64>):F64 {
    return ((x[0] : Float) * (y[0] : Float) + (x[1] : Float) * (y[1] : Float));
  }

  @:qdFunc
  public static function dot3F64(x:Vector<F64>, y:Vector<F64>):F64 {
    return ((x[0] : Float) * (y[0] : Float) + (x[1] : Float) * (y[1] : Float) + (x[2] : Float) * (y[2] : Float));
  }

  @:qdFunc
  public static function dot4F64(x:Vector<F64>, y:Vector<F64>):F64 {
    return ((x[0] : Float) * (y[0] : Float) + (x[1] : Float) * (y[1] : Float) + (x[2] : Float) * (y[2] : Float) + (x[3] : Float) * (y[3] : Float));
  }

  @:qdFunc
  public static function length2F64(x:Vector<F64>):F64 {
    return (Math.sqrt((dot2F64(x, x) : Float)));
  }

  @:qdFunc
  public static function length3F64(x:Vector<F64>):F64 {
    return (Math.sqrt((dot3F64(x, x) : Float)));
  }

  @:qdFunc
  public static function length4F64(x:Vector<F64>):F64 {
    return (Math.sqrt((dot4F64(x, x) : Float)));
  }

  @:qdFunc
  public static function distance2F64(x:Vector<F64>, y:Vector<F64>):F64 {
    return (Math.sqrt(((x[0] : Float) - (y[0] : Float)) * ((x[0] : Float) - (y[0] : Float)) + ((x[1] : Float) - (y[1] : Float)) * ((x[1] : Float) - (y[1] : Float))));
  }

  @:qdFunc
  public static function distance3F64(x:Vector<F64>, y:Vector<F64>):F64 {
    return (Math.sqrt(((x[0] : Float) - (y[0] : Float)) * ((x[0] : Float) - (y[0] : Float)) + ((x[1] : Float) - (y[1] : Float)) * ((x[1] : Float) - (y[1] : Float)) + ((x[2] : Float) - (y[2] : Float)) * ((x[2] : Float) - (y[2] : Float))));
  }

  @:qdFunc
  public static function distance4F64(x:Vector<F64>, y:Vector<F64>):F64 {
    return (Math.sqrt(((x[0] : Float) - (y[0] : Float)) * ((x[0] : Float) - (y[0] : Float)) + ((x[1] : Float) - (y[1] : Float)) * ((x[1] : Float) - (y[1] : Float)) + ((x[2] : Float) - (y[2] : Float)) * ((x[2] : Float) - (y[2] : Float)) + ((x[3] : Float) - (y[3] : Float)) * ((x[3] : Float) - (y[3] : Float))));
  }

  @:qdFunc
  public static function normalize2F64(x:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[0] : Float) / (length2F64(x) : Float)),
      ((x[1] : Float) / (length2F64(x) : Float))
    ]);
  }

  @:qdFunc
  public static function normalize3F64(x:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[0] : Float) / (length3F64(x) : Float)),
      ((x[1] : Float) / (length3F64(x) : Float)),
      ((x[2] : Float) / (length3F64(x) : Float))
    ]);
  }

  @:qdFunc
  public static function normalize4F64(x:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[0] : Float) / (length4F64(x) : Float)),
      ((x[1] : Float) / (length4F64(x) : Float)),
      ((x[2] : Float) / (length4F64(x) : Float)),
      ((x[3] : Float) / (length4F64(x) : Float))
    ]);
  }

  @:qdFunc
  public static function reflect2F64(x:Vector<F64>, n:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[0] : Float) - 2.0 * (dot2F64(x, n) : Float) * (n[0] : Float)),
      ((x[1] : Float) - 2.0 * (dot2F64(x, n) : Float) * (n[1] : Float))
    ]);
  }

  @:qdFunc
  public static function reflect3F64(x:Vector<F64>, n:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[0] : Float) - 2.0 * (dot3F64(x, n) : Float) * (n[0] : Float)),
      ((x[1] : Float) - 2.0 * (dot3F64(x, n) : Float) * (n[1] : Float)),
      ((x[2] : Float) - 2.0 * (dot3F64(x, n) : Float) * (n[2] : Float))
    ]);
  }

  @:qdFunc
  public static function reflect4F64(x:Vector<F64>, n:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[0] : Float) - 2.0 * (dot4F64(x, n) : Float) * (n[0] : Float)),
      ((x[1] : Float) - 2.0 * (dot4F64(x, n) : Float) * (n[1] : Float)),
      ((x[2] : Float) - 2.0 * (dot4F64(x, n) : Float) * (n[2] : Float)),
      ((x[3] : Float) - 2.0 * (dot4F64(x, n) : Float) * (n[3] : Float))
    ]);
  }

  @:qdFunc
  private static function refractK2F64(x:Vector<F64>, n:Vector<F64>, eta:F64):F64 {
    return (1.0 - (eta : Float) * (eta : Float) * (1.0 - (dot2F64(x, n) : Float) * (dot2F64(x, n) : Float)));
  }

  @:qdFunc
  private static function refractK3F64(x:Vector<F64>, n:Vector<F64>, eta:F64):F64 {
    return (1.0 - (eta : Float) * (eta : Float) * (1.0 - (dot3F64(x, n) : Float) * (dot3F64(x, n) : Float)));
  }

  @:qdFunc
  private static function refractK4F64(x:Vector<F64>, n:Vector<F64>, eta:F64):F64 {
    return (1.0 - (eta : Float) * (eta : Float) * (1.0 - (dot4F64(x, n) : Float) * (dot4F64(x, n) : Float)));
  }

  @:qdFunc
  public static function refract2F64(x:Vector<F64>, n:Vector<F64>, eta:F64):Vector<F64> {
    return Vector.ofArray([
      (refractK2F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[0] : Float) - ((eta : Float) * (dot2F64(x, n) : Float) + Math.sqrt((refractK2F64(x, n, eta) : Float))) * (n[0] : Float)) : (0.0),
      (refractK2F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[1] : Float) - ((eta : Float) * (dot2F64(x, n) : Float) + Math.sqrt((refractK2F64(x, n, eta) : Float))) * (n[1] : Float)) : (0.0)
    ]);
  }

  @:qdFunc
  public static function refract3F64(x:Vector<F64>, n:Vector<F64>, eta:F64):Vector<F64> {
    return Vector.ofArray([
      (refractK3F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[0] : Float) - ((eta : Float) * (dot3F64(x, n) : Float) + Math.sqrt((refractK3F64(x, n, eta) : Float))) * (n[0] : Float)) : (0.0),
      (refractK3F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[1] : Float) - ((eta : Float) * (dot3F64(x, n) : Float) + Math.sqrt((refractK3F64(x, n, eta) : Float))) * (n[1] : Float)) : (0.0),
      (refractK3F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[2] : Float) - ((eta : Float) * (dot3F64(x, n) : Float) + Math.sqrt((refractK3F64(x, n, eta) : Float))) * (n[2] : Float)) : (0.0)
    ]);
  }

  @:qdFunc
  public static function refract4F64(x:Vector<F64>, n:Vector<F64>, eta:F64):Vector<F64> {
    return Vector.ofArray([
      (refractK4F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[0] : Float) - ((eta : Float) * (dot4F64(x, n) : Float) + Math.sqrt((refractK4F64(x, n, eta) : Float))) * (n[0] : Float)) : (0.0),
      (refractK4F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[1] : Float) - ((eta : Float) * (dot4F64(x, n) : Float) + Math.sqrt((refractK4F64(x, n, eta) : Float))) * (n[1] : Float)) : (0.0),
      (refractK4F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[2] : Float) - ((eta : Float) * (dot4F64(x, n) : Float) + Math.sqrt((refractK4F64(x, n, eta) : Float))) * (n[2] : Float)) : (0.0),
      (refractK4F64(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[3] : Float) - ((eta : Float) * (dot4F64(x, n) : Float) + Math.sqrt((refractK4F64(x, n, eta) : Float))) * (n[3] : Float)) : (0.0)
    ]);
  }

  @:qdFunc
  public static function cross3F64(x:Vector<F64>, y:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((x[1] : Float) * (y[2] : Float) - (x[2] : Float) * (y[1] : Float)),
      ((x[2] : Float) * (y[0] : Float) - (x[0] : Float) * (y[2] : Float)),
      ((x[0] : Float) * (y[1] : Float) - (x[1] : Float) * (y[0] : Float))
    ]);
  }

  @:qdFunc
  public static function vdirF64(angle:F64):Vector<F64> {
    return Vector.ofArray([
      (Math.cos((angle : Float))),
      (Math.sin((angle : Float)))
    ]);
  }

  @:qdFunc
  public static function translateF64(dx:F64, dy:F64, dz:F64):Matrix<F64> {
    return Matrix.ofArray(4, 4, [
      (1.0), (0.0), (0.0), dx,
      (0.0), (1.0), (0.0), dy,
      (0.0), (0.0), (1.0), dz,
      (0.0), (0.0), (0.0), (1.0)
    ]);
  }

  @:qdFunc
  public static function scaleF64(sx:F64, sy:F64, sz:F64):Matrix<F64> {
    return Matrix.ofArray(4, 4, [
      sx, (0.0), (0.0), (0.0),
      (0.0), sy, (0.0), (0.0),
      (0.0), (0.0), sz, (0.0),
      (0.0), (0.0), (0.0), (1.0)
    ]);
  }

  @:qdFunc
  public static function rotation2dF64(angle:F64):Matrix<F64> {
    return Matrix.ofArray(2, 2, [
      (Math.cos((angle : Float))), (-Math.sin((angle : Float))),
      (Math.sin((angle : Float))), (Math.cos((angle : Float)))
    ]);
  }

  @:qdFunc
  public static function rotByAxisF64(axis:Vector<F64>, angle:F64):Matrix<F64> {
    return Matrix.ofArray(4, 4, [
      (Math.cos((angle : Float)) + (1.0 - Math.cos((angle : Float))) * ((axis[0] : Float) / (length3F64(axis) : Float)) * ((axis[0] : Float) / (length3F64(axis) : Float))),
      ((1.0 - Math.cos((angle : Float))) * ((axis[0] : Float) / (length3F64(axis) : Float)) * ((axis[1] : Float) / (length3F64(axis) : Float)) + Math.sin((angle : Float)) * ((axis[2] : Float) / (length3F64(axis) : Float))),
      ((1.0 - Math.cos((angle : Float))) * ((axis[0] : Float) / (length3F64(axis) : Float)) * ((axis[2] : Float) / (length3F64(axis) : Float)) - Math.sin((angle : Float)) * ((axis[1] : Float) / (length3F64(axis) : Float))),
      (0.0),
      ((1.0 - Math.cos((angle : Float))) * ((axis[1] : Float) / (length3F64(axis) : Float)) * ((axis[0] : Float) / (length3F64(axis) : Float)) - Math.sin((angle : Float)) * ((axis[2] : Float) / (length3F64(axis) : Float))),
      (Math.cos((angle : Float)) + (1.0 - Math.cos((angle : Float))) * ((axis[1] : Float) / (length3F64(axis) : Float)) * ((axis[1] : Float) / (length3F64(axis) : Float))),
      ((1.0 - Math.cos((angle : Float))) * ((axis[1] : Float) / (length3F64(axis) : Float)) * ((axis[2] : Float) / (length3F64(axis) : Float)) + Math.sin((angle : Float)) * ((axis[0] : Float) / (length3F64(axis) : Float))),
      (0.0),
      ((1.0 - Math.cos((angle : Float))) * ((axis[2] : Float) / (length3F64(axis) : Float)) * ((axis[0] : Float) / (length3F64(axis) : Float)) + Math.sin((angle : Float)) * ((axis[1] : Float) / (length3F64(axis) : Float))),
      ((1.0 - Math.cos((angle : Float))) * ((axis[2] : Float) / (length3F64(axis) : Float)) * ((axis[1] : Float) / (length3F64(axis) : Float)) - Math.sin((angle : Float)) * ((axis[0] : Float) / (length3F64(axis) : Float))),
      (Math.cos((angle : Float)) + (1.0 - Math.cos((angle : Float))) * ((axis[2] : Float) / (length3F64(axis) : Float)) * ((axis[2] : Float) / (length3F64(axis) : Float))),
      (0.0),
      (0.0), (0.0), (0.0), (1.0)
    ]);
  }

  @:qdFunc
  public static function rotYawPitchRollF64(yaw:F64, pitch:F64, roll:F64):Matrix<F64> {
    return Matrix.ofArray(4, 4, [
      (Math.cos((yaw : Float)) * Math.cos((roll : Float)) + Math.sin((yaw : Float)) * Math.sin((pitch : Float)) * Math.sin((roll : Float))),
      (Math.sin((roll : Float)) * Math.cos((pitch : Float))),
      (-Math.sin((yaw : Float)) * Math.cos((roll : Float)) + Math.cos((yaw : Float)) * Math.sin((pitch : Float)) * Math.sin((roll : Float))),
      (0.0),
      (-Math.cos((yaw : Float)) * Math.sin((roll : Float)) + Math.sin((yaw : Float)) * Math.sin((pitch : Float)) * Math.cos((roll : Float))),
      (Math.cos((roll : Float)) * Math.cos((pitch : Float))),
      (Math.sin((roll : Float)) * Math.sin((yaw : Float)) + Math.cos((yaw : Float)) * Math.sin((pitch : Float)) * Math.cos((roll : Float))),
      (0.0),
      (Math.sin((yaw : Float)) * Math.cos((pitch : Float))),
      (-Math.sin((pitch : Float))),
      (Math.cos((yaw : Float)) * Math.cos((pitch : Float))),
      (0.0),
      (0.0), (0.0), (0.0), (1.0)
    ]);
  }

  @:qdFunc
  public static function rotation3dF64(angleX:F64, angleY:F64, angleZ:F64):Matrix<F64> {
    return rotYawPitchRollF64(angleZ, angleX, angleY);
  }
}

/** F64 signature for `select`, which the kernel frontend lowers as an intrinsic. */
private class MathF64Builtin {
  public static function select(condition:Bool, ifTrue:F64, ifFalse:F64):F64 {
    throw "Quadrants MathF64Builtin.select is a kernel-only intrinsic";
  }
}
