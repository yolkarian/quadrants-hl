package quadrants.math;

import quadrants.Matrix;
import quadrants.Vector;
import quadrants.Types.F32;

/** Kernel-local GLSL-style helpers for explicit F32 values. */
class MathF32 {
  @:qdFunc
  public static function mixF32(x:F32, y:F32, a:F32):F32 {
    return ((x : Float) * (1.0 - (a : Float)) + (y : Float) * (a : Float) : F32);
  }

  @:qdFunc
  public static function clampF32(x:F32, xmin:F32, xmax:F32):F32 {
    return (Math.min((xmax : Float), Math.max((xmin : Float), (x : Float))) : F32);
  }

  @:qdFunc
  public static function stepF32(edge:F32, x:F32):F32 {
    return (x : Float) < (edge : Float) ? (0.0 : F32) : (1.0 : F32);
  }

  @:qdFunc
  public static function fractF32(x:F32):F32 {
    return ((x : Float) - Math.floor(x : Float) : F32);
  }

  @:qdFunc
  public static function smoothstepF32(edge0:F32, edge1:F32, x:F32):F32 {
    var t:F32 = clampF32((((x : Float) - (edge0 : Float)) / ((edge1 : Float) - (edge0 : Float)) : F32), (0.0 : F32), (1.0 : F32));
    return ((t : Float) * (t : Float) * (3.0 - 2.0 * (t : Float)) : F32);
  }

  @:qdFunc
  public static function signF32(x:F32):F32 {
    return (x : Float) < 0.0 ? (-1.0 : F32) : ((x : Float) > 0.0 ? (1.0 : F32) : (0.0 : F32));
  }

  @:qdFunc
  public static function log2F32(x:F32):F32 {
    return (Math.log(x : Float) / Math.log(2.0) : F32);
  }

  @:qdFunc
  public static function degreesF32(x:F32):F32 {
    return ((x : Float) * 57.295779513082320876798154814105 : F32);
  }

  @:qdFunc
  public static function radiansF32(x:F32):F32 {
    return ((x : Float) * 0.017453292519943295769236907684886 : F32);
  }

  @:qdFunc
  public static function modF32(x:F32, y:F32):F32 {
    return ((x : Float) - (y : Float) * Math.floor((x : Float) / (y : Float)) : F32);
  }

  @:qdFunc
  public static function isinfF32(x:F32):Bool {
    return (x : Float) == (x : Float) && ((x : Float) - (x : Float)) != ((x : Float) - (x : Float));
  }

  @:qdFunc
  public static function isnanF32(x:F32):Bool {
    return (x : Float) != (x : Float);
  }

  @:qdFunc
  public static function dot2F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return ((x[0] : Float) * (y[0] : Float) + (x[1] : Float) * (y[1] : Float) : F32);
  }

  @:qdFunc
  public static function dot3F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return ((x[0] : Float) * (y[0] : Float) + (x[1] : Float) * (y[1] : Float) + (x[2] : Float) * (y[2] : Float) : F32);
  }

  @:qdFunc
  public static function dot4F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return ((x[0] : Float) * (y[0] : Float) + (x[1] : Float) * (y[1] : Float) + (x[2] : Float) * (y[2] : Float) + (x[3] : Float) * (y[3] : Float) : F32);
  }

  @:qdFunc
  public static function length2F32(x:Vector<F32>):F32 {
    return (Math.sqrt(dot2F32(x, x) : Float) : F32);
  }

  @:qdFunc
  public static function length3F32(x:Vector<F32>):F32 {
    return (Math.sqrt(dot3F32(x, x) : Float) : F32);
  }

  @:qdFunc
  public static function length4F32(x:Vector<F32>):F32 {
    return (Math.sqrt(dot4F32(x, x) : Float) : F32);
  }

  @:qdFunc
  public static function distance2F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return (Math.sqrt(((x[0] : Float) - (y[0] : Float)) * ((x[0] : Float) - (y[0] : Float)) + ((x[1] : Float) - (y[1] : Float)) * ((x[1] : Float) - (y[1] : Float))) : F32);
  }

  @:qdFunc
  public static function distance3F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return (Math.sqrt(((x[0] : Float) - (y[0] : Float)) * ((x[0] : Float) - (y[0] : Float)) + ((x[1] : Float) - (y[1] : Float)) * ((x[1] : Float) - (y[1] : Float)) + ((x[2] : Float) - (y[2] : Float)) * ((x[2] : Float) - (y[2] : Float))) : F32);
  }

  @:qdFunc
  public static function distance4F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return (Math.sqrt(((x[0] : Float) - (y[0] : Float)) * ((x[0] : Float) - (y[0] : Float)) + ((x[1] : Float) - (y[1] : Float)) * ((x[1] : Float) - (y[1] : Float)) + ((x[2] : Float) - (y[2] : Float)) * ((x[2] : Float) - (y[2] : Float)) + ((x[3] : Float) - (y[3] : Float)) * ((x[3] : Float) - (y[3] : Float))) : F32);
  }

  @:qdFunc
  public static function normalize2F32(x:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : Float) / (length2F32(x) : Float) : F32),
      ((x[1] : Float) / (length2F32(x) : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function normalize3F32(x:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : Float) / (length3F32(x) : Float) : F32),
      ((x[1] : Float) / (length3F32(x) : Float) : F32),
      ((x[2] : Float) / (length3F32(x) : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function normalize4F32(x:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : Float) / (length4F32(x) : Float) : F32),
      ((x[1] : Float) / (length4F32(x) : Float) : F32),
      ((x[2] : Float) / (length4F32(x) : Float) : F32),
      ((x[3] : Float) / (length4F32(x) : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function reflect2F32(x:Vector<F32>, n:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : Float) - 2.0 * (dot2F32(x, n) : Float) * (n[0] : Float) : F32),
      ((x[1] : Float) - 2.0 * (dot2F32(x, n) : Float) * (n[1] : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function reflect3F32(x:Vector<F32>, n:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : Float) - 2.0 * (dot3F32(x, n) : Float) * (n[0] : Float) : F32),
      ((x[1] : Float) - 2.0 * (dot3F32(x, n) : Float) * (n[1] : Float) : F32),
      ((x[2] : Float) - 2.0 * (dot3F32(x, n) : Float) * (n[2] : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function reflect4F32(x:Vector<F32>, n:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : Float) - 2.0 * (dot4F32(x, n) : Float) * (n[0] : Float) : F32),
      ((x[1] : Float) - 2.0 * (dot4F32(x, n) : Float) * (n[1] : Float) : F32),
      ((x[2] : Float) - 2.0 * (dot4F32(x, n) : Float) * (n[2] : Float) : F32),
      ((x[3] : Float) - 2.0 * (dot4F32(x, n) : Float) * (n[3] : Float) : F32)
    ]);
  }

  @:qdFunc
  private static function refractK2F32(x:Vector<F32>, n:Vector<F32>, eta:F32):F32 {
    return (1.0 - (eta : Float) * (eta : Float) * (1.0 - (dot2F32(x, n) : Float) * (dot2F32(x, n) : Float)) : F32);
  }

  @:qdFunc
  private static function refractK3F32(x:Vector<F32>, n:Vector<F32>, eta:F32):F32 {
    return (1.0 - (eta : Float) * (eta : Float) * (1.0 - (dot3F32(x, n) : Float) * (dot3F32(x, n) : Float)) : F32);
  }

  @:qdFunc
  private static function refractK4F32(x:Vector<F32>, n:Vector<F32>, eta:F32):F32 {
    return (1.0 - (eta : Float) * (eta : Float) * (1.0 - (dot4F32(x, n) : Float) * (dot4F32(x, n) : Float)) : F32);
  }

  @:qdFunc
  public static function refract2F32(x:Vector<F32>, n:Vector<F32>, eta:F32):Vector<F32> {
    return Vector.ofArray([
      (refractK2F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[0] : Float) - ((eta : Float) * (dot2F32(x, n) : Float) + Math.sqrt(refractK2F32(x, n, eta) : Float)) * (n[0] : Float) : F32) : (0.0 : F32),
      (refractK2F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[1] : Float) - ((eta : Float) * (dot2F32(x, n) : Float) + Math.sqrt(refractK2F32(x, n, eta) : Float)) * (n[1] : Float) : F32) : (0.0 : F32)
    ]);
  }

  @:qdFunc
  public static function refract3F32(x:Vector<F32>, n:Vector<F32>, eta:F32):Vector<F32> {
    return Vector.ofArray([
      (refractK3F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[0] : Float) - ((eta : Float) * (dot3F32(x, n) : Float) + Math.sqrt(refractK3F32(x, n, eta) : Float)) * (n[0] : Float) : F32) : (0.0 : F32),
      (refractK3F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[1] : Float) - ((eta : Float) * (dot3F32(x, n) : Float) + Math.sqrt(refractK3F32(x, n, eta) : Float)) * (n[1] : Float) : F32) : (0.0 : F32),
      (refractK3F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[2] : Float) - ((eta : Float) * (dot3F32(x, n) : Float) + Math.sqrt(refractK3F32(x, n, eta) : Float)) * (n[2] : Float) : F32) : (0.0 : F32)
    ]);
  }

  @:qdFunc
  public static function refract4F32(x:Vector<F32>, n:Vector<F32>, eta:F32):Vector<F32> {
    return Vector.ofArray([
      (refractK4F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[0] : Float) - ((eta : Float) * (dot4F32(x, n) : Float) + Math.sqrt(refractK4F32(x, n, eta) : Float)) * (n[0] : Float) : F32) : (0.0 : F32),
      (refractK4F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[1] : Float) - ((eta : Float) * (dot4F32(x, n) : Float) + Math.sqrt(refractK4F32(x, n, eta) : Float)) * (n[1] : Float) : F32) : (0.0 : F32),
      (refractK4F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[2] : Float) - ((eta : Float) * (dot4F32(x, n) : Float) + Math.sqrt(refractK4F32(x, n, eta) : Float)) * (n[2] : Float) : F32) : (0.0 : F32),
      (refractK4F32(x, n, eta) : Float) >= 0.0 ? ((eta : Float) * (x[3] : Float) - ((eta : Float) * (dot4F32(x, n) : Float) + Math.sqrt(refractK4F32(x, n, eta) : Float)) * (n[3] : Float) : F32) : (0.0 : F32)
    ]);
  }

  @:qdFunc
  public static function cross3F32(x:Vector<F32>, y:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[1] : Float) * (y[2] : Float) - (x[2] : Float) * (y[1] : Float) : F32),
      ((x[2] : Float) * (y[0] : Float) - (x[0] : Float) * (y[2] : Float) : F32),
      ((x[0] : Float) * (y[1] : Float) - (x[1] : Float) * (y[0] : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function vdirF32(angle:F32):Vector<F32> {
    return Vector.ofArray([
      (Math.cos(angle : Float) : F32),
      (Math.sin(angle : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function translateF32(dx:F32, dy:F32, dz:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      (1.0 : F32), (0.0 : F32), (0.0 : F32), dx,
      (0.0 : F32), (1.0 : F32), (0.0 : F32), dy,
      (0.0 : F32), (0.0 : F32), (1.0 : F32), dz,
      (0.0 : F32), (0.0 : F32), (0.0 : F32), (1.0 : F32)
    ]);
  }

  @:qdFunc
  public static function scaleF32(sx:F32, sy:F32, sz:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      sx, (0.0 : F32), (0.0 : F32), (0.0 : F32),
      (0.0 : F32), sy, (0.0 : F32), (0.0 : F32),
      (0.0 : F32), (0.0 : F32), sz, (0.0 : F32),
      (0.0 : F32), (0.0 : F32), (0.0 : F32), (1.0 : F32)
    ]);
  }

  @:qdFunc
  public static function rotation2dF32(angle:F32):Matrix<F32> {
    return Matrix.ofArray(2, 2, [
      (Math.cos(angle : Float) : F32), (-Math.sin(angle : Float) : F32),
      (Math.sin(angle : Float) : F32), (Math.cos(angle : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function rotByAxisF32(axis:Vector<F32>, angle:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      (Math.cos(angle : Float) + (1.0 - Math.cos(angle : Float)) * ((axis[0] : Float) / (length3F32(axis) : Float)) * ((axis[0] : Float) / (length3F32(axis) : Float)) : F32),
      ((1.0 - Math.cos(angle : Float)) * ((axis[0] : Float) / (length3F32(axis) : Float)) * ((axis[1] : Float) / (length3F32(axis) : Float)) + Math.sin(angle : Float) * ((axis[2] : Float) / (length3F32(axis) : Float)) : F32),
      ((1.0 - Math.cos(angle : Float)) * ((axis[0] : Float) / (length3F32(axis) : Float)) * ((axis[2] : Float) / (length3F32(axis) : Float)) - Math.sin(angle : Float) * ((axis[1] : Float) / (length3F32(axis) : Float)) : F32),
      (0.0 : F32),
      ((1.0 - Math.cos(angle : Float)) * ((axis[1] : Float) / (length3F32(axis) : Float)) * ((axis[0] : Float) / (length3F32(axis) : Float)) - Math.sin(angle : Float) * ((axis[2] : Float) / (length3F32(axis) : Float)) : F32),
      (Math.cos(angle : Float) + (1.0 - Math.cos(angle : Float)) * ((axis[1] : Float) / (length3F32(axis) : Float)) * ((axis[1] : Float) / (length3F32(axis) : Float)) : F32),
      ((1.0 - Math.cos(angle : Float)) * ((axis[1] : Float) / (length3F32(axis) : Float)) * ((axis[2] : Float) / (length3F32(axis) : Float)) + Math.sin(angle : Float) * ((axis[0] : Float) / (length3F32(axis) : Float)) : F32),
      (0.0 : F32),
      ((1.0 - Math.cos(angle : Float)) * ((axis[2] : Float) / (length3F32(axis) : Float)) * ((axis[0] : Float) / (length3F32(axis) : Float)) + Math.sin(angle : Float) * ((axis[1] : Float) / (length3F32(axis) : Float)) : F32),
      ((1.0 - Math.cos(angle : Float)) * ((axis[2] : Float) / (length3F32(axis) : Float)) * ((axis[1] : Float) / (length3F32(axis) : Float)) - Math.sin(angle : Float) * ((axis[0] : Float) / (length3F32(axis) : Float)) : F32),
      (Math.cos(angle : Float) + (1.0 - Math.cos(angle : Float)) * ((axis[2] : Float) / (length3F32(axis) : Float)) * ((axis[2] : Float) / (length3F32(axis) : Float)) : F32),
      (0.0 : F32),
      (0.0 : F32), (0.0 : F32), (0.0 : F32), (1.0 : F32)
    ]);
  }

  @:qdFunc
  public static function rotYawPitchRollF32(yaw:F32, pitch:F32, roll:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      (Math.cos(yaw : Float) * Math.cos(roll : Float) + Math.sin(yaw : Float) * Math.sin(pitch : Float) * Math.sin(roll : Float) : F32),
      (Math.sin(roll : Float) * Math.cos(pitch : Float) : F32),
      (-Math.sin(yaw : Float) * Math.cos(roll : Float) + Math.cos(yaw : Float) * Math.sin(pitch : Float) * Math.sin(roll : Float) : F32),
      (0.0 : F32),
      (-Math.cos(yaw : Float) * Math.sin(roll : Float) + Math.sin(yaw : Float) * Math.sin(pitch : Float) * Math.cos(roll : Float) : F32),
      (Math.cos(roll : Float) * Math.cos(pitch : Float) : F32),
      (Math.sin(roll : Float) * Math.sin(yaw : Float) + Math.cos(yaw : Float) * Math.sin(pitch : Float) * Math.cos(roll : Float) : F32),
      (0.0 : F32),
      (Math.sin(yaw : Float) * Math.cos(pitch : Float) : F32),
      (-Math.sin(pitch : Float) : F32),
      (Math.cos(yaw : Float) * Math.cos(pitch : Float) : F32),
      (0.0 : F32),
      (0.0 : F32), (0.0 : F32), (0.0 : F32), (1.0 : F32)
    ]);
  }

  @:qdFunc
  public static function rotation3dF32(angleX:F32, angleY:F32, angleZ:F32):Matrix<F32> {
    return rotYawPitchRollF32(angleZ, angleX, angleY);
  }
}
