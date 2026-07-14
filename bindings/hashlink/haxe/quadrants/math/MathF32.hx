package quadrants.math;

import quadrants.Matrix;
import quadrants.Vector;
import quadrants.Types.F32;

/** Kernel-local GLSL-style helpers for explicit F32 values. */
class MathF32 {
  @:qdFunc
  private static function mathLiteralF32(value:F32):F32 {
    return value;
  }

  @:qdFunc
  public static function mixF32(x:F32, y:F32, a:F32):F32 {
    return ((x : hl.F32) * (1 - (a : hl.F32)) + (y : hl.F32) * (a : hl.F32) : F32);
  }

  @:qdFunc
  public static function clampF32(x:F32, xmin:F32, xmax:F32):F32 {
    return MathF32Builtin.min(xmax, MathF32Builtin.max(xmin, x));
  }

  @:qdFunc
  public static function stepF32(edge:F32, x:F32):F32 {
    return MathF32Builtin.select(
      (x : hl.F32) < (edge : hl.F32),
      (x : hl.F32) - (x : hl.F32),
      (x : hl.F32) - (x : hl.F32) + 1);
  }

  @:qdFunc
  public static function fractF32(x:F32):F32 {
    return ((x : hl.F32) - (MathF32Builtin.floor(x) : hl.F32) : F32);
  }

  @:qdFunc
  public static function smoothstepF32(edge0:F32, edge1:F32, x:F32):F32 {
    return ((clampF32(
        MathF32Builtin.rawDiv((x : hl.F32) - (edge0 : hl.F32), (edge1 : hl.F32) - (edge0 : hl.F32)),
        (x : hl.F32) - (x : hl.F32),
        (x : hl.F32) - (x : hl.F32) + 1) : hl.F32)
      * (clampF32(
        MathF32Builtin.rawDiv((x : hl.F32) - (edge0 : hl.F32), (edge1 : hl.F32) - (edge0 : hl.F32)),
        (x : hl.F32) - (x : hl.F32),
        (x : hl.F32) - (x : hl.F32) + 1) : hl.F32)
      * (3 - 2 * (clampF32(
        MathF32Builtin.rawDiv((x : hl.F32) - (edge0 : hl.F32), (edge1 : hl.F32) - (edge0 : hl.F32)),
        (x : hl.F32) - (x : hl.F32),
        (x : hl.F32) - (x : hl.F32) + 1) : hl.F32)) : F32);
  }

  @:qdFunc
  public static function signF32(x:F32):F32 {
    return MathF32Builtin.select(
      (x : hl.F32) < 0,
      (x : hl.F32) - (x : hl.F32) - 1,
      MathF32Builtin.select(
        (x : hl.F32) > 0,
        (x : hl.F32) - (x : hl.F32) + 1,
        (x : hl.F32) - (x : hl.F32)));
  }

  @:qdFunc
  public static function log2F32(x:F32):F32 {
    return MathF32Builtin.rawDiv(MathF32Builtin.log(x), MathF32Builtin.log((mathLiteralF32(2.0) : hl.F32)));
  }

  @:qdFunc
  public static function degreesF32(x:F32):F32 {
    return ((x : hl.F32) * (mathLiteralF32(57.295779513082320876798154814105) : hl.F32) : F32);
  }

  @:qdFunc
  public static function radiansF32(x:F32):F32 {
    return ((x : hl.F32) * (mathLiteralF32(0.017453292519943295769236907684886) : hl.F32) : F32);
  }

  @:qdFunc
  public static function modF32(x:F32, y:F32):F32 {
    return ((x : hl.F32) - (y : hl.F32) * (MathF32Builtin.floor(MathF32Builtin.rawDiv(x, y)) : hl.F32) : F32);
  }

  @:qdFunc
  public static function isinfF32(x:F32):Bool {
    return (x : hl.F32) == (x : hl.F32) && ((x : hl.F32) - (x : hl.F32)) != ((x : hl.F32) - (x : hl.F32));
  }

  @:qdFunc
  public static function isnanF32(x:F32):Bool {
    return (x : hl.F32) != (x : hl.F32);
  }

  @:qdFunc
  public static function dot2F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return ((x[0] : hl.F32) * (y[0] : hl.F32) + (x[1] : hl.F32) * (y[1] : hl.F32) : F32);
  }

  @:qdFunc
  public static function dot3F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return ((x[0] : hl.F32) * (y[0] : hl.F32) + (x[1] : hl.F32) * (y[1] : hl.F32) + (x[2] : hl.F32) * (y[2] : hl.F32) : F32);
  }

  @:qdFunc
  public static function dot4F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return ((x[0] : hl.F32) * (y[0] : hl.F32) + (x[1] : hl.F32) * (y[1] : hl.F32) + (x[2] : hl.F32) * (y[2] : hl.F32) + (x[3] : hl.F32) * (y[3] : hl.F32) : F32);
  }

  @:qdFunc
  public static function length2F32(x:Vector<F32>):F32 {
    return MathF32Builtin.sqrt(dot2F32(x, x));
  }

  @:qdFunc
  public static function length3F32(x:Vector<F32>):F32 {
    return MathF32Builtin.sqrt(dot3F32(x, x));
  }

  @:qdFunc
  public static function length4F32(x:Vector<F32>):F32 {
    return MathF32Builtin.sqrt(dot4F32(x, x));
  }

  @:qdFunc
  public static function distance2F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return MathF32Builtin.sqrt((((x[0] : hl.F32) - (y[0] : hl.F32)) * ((x[0] : hl.F32) - (y[0] : hl.F32)) + ((x[1] : hl.F32) - (y[1] : hl.F32)) * ((x[1] : hl.F32) - (y[1] : hl.F32)) : F32));
  }

  @:qdFunc
  public static function distance3F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return MathF32Builtin.sqrt((((x[0] : hl.F32) - (y[0] : hl.F32)) * ((x[0] : hl.F32) - (y[0] : hl.F32)) + ((x[1] : hl.F32) - (y[1] : hl.F32)) * ((x[1] : hl.F32) - (y[1] : hl.F32)) + ((x[2] : hl.F32) - (y[2] : hl.F32)) * ((x[2] : hl.F32) - (y[2] : hl.F32)) : F32));
  }

  @:qdFunc
  public static function distance4F32(x:Vector<F32>, y:Vector<F32>):F32 {
    return MathF32Builtin.sqrt((((x[0] : hl.F32) - (y[0] : hl.F32)) * ((x[0] : hl.F32) - (y[0] : hl.F32)) + ((x[1] : hl.F32) - (y[1] : hl.F32)) * ((x[1] : hl.F32) - (y[1] : hl.F32)) + ((x[2] : hl.F32) - (y[2] : hl.F32)) * ((x[2] : hl.F32) - (y[2] : hl.F32)) + ((x[3] : hl.F32) - (y[3] : hl.F32)) * ((x[3] : hl.F32) - (y[3] : hl.F32)) : F32));
  }

  @:qdFunc
  public static function normalize2F32(x:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      MathF32Builtin.rawDiv(x[0], length2F32(x)),
      MathF32Builtin.rawDiv(x[1], length2F32(x))
    ]);
  }

  @:qdFunc
  public static function normalize3F32(x:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      MathF32Builtin.rawDiv(x[0], length3F32(x)),
      MathF32Builtin.rawDiv(x[1], length3F32(x)),
      MathF32Builtin.rawDiv(x[2], length3F32(x))
    ]);
  }

  @:qdFunc
  public static function normalize4F32(x:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      MathF32Builtin.rawDiv(x[0], length4F32(x)),
      MathF32Builtin.rawDiv(x[1], length4F32(x)),
      MathF32Builtin.rawDiv(x[2], length4F32(x)),
      MathF32Builtin.rawDiv(x[3], length4F32(x))
    ]);
  }

  @:qdFunc
  public static function reflect2F32(x:Vector<F32>, n:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : hl.F32) - 2 * (dot2F32(x, n) : hl.F32) * (n[0] : hl.F32) : F32),
      ((x[1] : hl.F32) - 2 * (dot2F32(x, n) : hl.F32) * (n[1] : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function reflect3F32(x:Vector<F32>, n:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : hl.F32) - 2 * (dot3F32(x, n) : hl.F32) * (n[0] : hl.F32) : F32),
      ((x[1] : hl.F32) - 2 * (dot3F32(x, n) : hl.F32) * (n[1] : hl.F32) : F32),
      ((x[2] : hl.F32) - 2 * (dot3F32(x, n) : hl.F32) * (n[2] : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function reflect4F32(x:Vector<F32>, n:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[0] : hl.F32) - 2 * (dot4F32(x, n) : hl.F32) * (n[0] : hl.F32) : F32),
      ((x[1] : hl.F32) - 2 * (dot4F32(x, n) : hl.F32) * (n[1] : hl.F32) : F32),
      ((x[2] : hl.F32) - 2 * (dot4F32(x, n) : hl.F32) * (n[2] : hl.F32) : F32),
      ((x[3] : hl.F32) - 2 * (dot4F32(x, n) : hl.F32) * (n[3] : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  private static function refractK2F32(x:Vector<F32>, n:Vector<F32>, eta:F32):F32 {
    return (1 - (eta : hl.F32) * (eta : hl.F32) * (1 - (dot2F32(x, n) : hl.F32) * (dot2F32(x, n) : hl.F32)) : F32);
  }

  @:qdFunc
  private static function refractK3F32(x:Vector<F32>, n:Vector<F32>, eta:F32):F32 {
    return (1 - (eta : hl.F32) * (eta : hl.F32) * (1 - (dot3F32(x, n) : hl.F32) * (dot3F32(x, n) : hl.F32)) : F32);
  }

  @:qdFunc
  private static function refractK4F32(x:Vector<F32>, n:Vector<F32>, eta:F32):F32 {
    return (1 - (eta : hl.F32) * (eta : hl.F32) * (1 - (dot4F32(x, n) : hl.F32) * (dot4F32(x, n) : hl.F32)) : F32);
  }

  @:qdFunc
  public static function refract2F32(x:Vector<F32>, n:Vector<F32>, eta:F32):Vector<F32> {
    return Vector.ofArray([
      (refractK2F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[0] : hl.F32) - ((eta : hl.F32) * (dot2F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK2F32(x, n, eta)) : hl.F32)) * (n[0] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32)),
      (refractK2F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[1] : hl.F32) - ((eta : hl.F32) * (dot2F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK2F32(x, n, eta)) : hl.F32)) * (n[1] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32))
    ]);
  }

  @:qdFunc
  public static function refract3F32(x:Vector<F32>, n:Vector<F32>, eta:F32):Vector<F32> {
    return Vector.ofArray([
      (refractK3F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[0] : hl.F32) - ((eta : hl.F32) * (dot3F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK3F32(x, n, eta)) : hl.F32)) * (n[0] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32)),
      (refractK3F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[1] : hl.F32) - ((eta : hl.F32) * (dot3F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK3F32(x, n, eta)) : hl.F32)) * (n[1] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32)),
      (refractK3F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[2] : hl.F32) - ((eta : hl.F32) * (dot3F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK3F32(x, n, eta)) : hl.F32)) * (n[2] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32))
    ]);
  }

  @:qdFunc
  public static function refract4F32(x:Vector<F32>, n:Vector<F32>, eta:F32):Vector<F32> {
    return Vector.ofArray([
      (refractK4F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[0] : hl.F32) - ((eta : hl.F32) * (dot4F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK4F32(x, n, eta)) : hl.F32)) * (n[0] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32)),
      (refractK4F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[1] : hl.F32) - ((eta : hl.F32) * (dot4F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK4F32(x, n, eta)) : hl.F32)) * (n[1] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32)),
      (refractK4F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[2] : hl.F32) - ((eta : hl.F32) * (dot4F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK4F32(x, n, eta)) : hl.F32)) * (n[2] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32)),
      (refractK4F32(x, n, eta) : hl.F32) >= 0 ? ((eta : hl.F32) * (x[3] : hl.F32) - ((eta : hl.F32) * (dot4F32(x, n) : hl.F32) + (MathF32Builtin.sqrt(refractK4F32(x, n, eta)) : hl.F32)) * (n[3] : hl.F32) : F32) : ((eta : hl.F32) - (eta : hl.F32))
    ]);
  }

  @:qdFunc
  public static function cross3F32(x:Vector<F32>, y:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((x[1] : hl.F32) * (y[2] : hl.F32) - (x[2] : hl.F32) * (y[1] : hl.F32) : F32),
      ((x[2] : hl.F32) * (y[0] : hl.F32) - (x[0] : hl.F32) * (y[2] : hl.F32) : F32),
      ((x[0] : hl.F32) * (y[1] : hl.F32) - (x[1] : hl.F32) * (y[0] : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function vdirF32(angle:F32):Vector<F32> {
    return Vector.ofArray([
      ((MathF32Builtin.cos(angle) : hl.F32) : F32),
      ((MathF32Builtin.sin(angle) : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function translateF32(dx:F32, dy:F32, dz:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      (mathLiteralF32(1.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), dx,
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(1.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), dy,
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(1.0) : hl.F32), dz,
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(1.0) : hl.F32)
    ]);
  }

  @:qdFunc
  public static function scaleF32(sx:F32, sy:F32, sz:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      sx, (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32),
      (mathLiteralF32(0.0) : hl.F32), sy, (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32),
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), sz, (mathLiteralF32(0.0) : hl.F32),
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(1.0) : hl.F32)
    ]);
  }

  @:qdFunc
  public static function rotation2dF32(angle:F32):Matrix<F32> {
    return Matrix.ofArray(2, 2, [
      ((MathF32Builtin.cos(angle) : hl.F32) : F32), (-(MathF32Builtin.sin(angle) : hl.F32) : F32),
      ((MathF32Builtin.sin(angle) : hl.F32) : F32), ((MathF32Builtin.cos(angle) : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function rotByAxisF32(axis:Vector<F32>, angle:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      ((MathF32Builtin.cos(angle) : hl.F32) + (1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) : F32),
      ((1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) + (MathF32Builtin.sin(angle) : hl.F32) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) : F32),
      ((1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) - (MathF32Builtin.sin(angle) : hl.F32) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) : F32),
      (mathLiteralF32(0.0) : hl.F32),
      ((1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) - (MathF32Builtin.sin(angle) : hl.F32) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) : F32),
      ((MathF32Builtin.cos(angle) : hl.F32) + (1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) : F32),
      ((1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) + (MathF32Builtin.sin(angle) : hl.F32) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) : F32),
      (mathLiteralF32(0.0) : hl.F32),
      ((1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) + (MathF32Builtin.sin(angle) : hl.F32) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) : F32),
      ((1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[1], length3F32(axis)) : hl.F32) - (MathF32Builtin.sin(angle) : hl.F32) * (MathF32Builtin.rawDiv(axis[0], length3F32(axis)) : hl.F32) : F32),
      ((MathF32Builtin.cos(angle) : hl.F32) + (1 - (MathF32Builtin.cos(angle) : hl.F32)) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) * (MathF32Builtin.rawDiv(axis[2], length3F32(axis)) : hl.F32) : F32),
      (mathLiteralF32(0.0) : hl.F32),
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(1.0) : hl.F32)
    ]);
  }

  @:qdFunc
  public static function rotYawPitchRollF32(yaw:F32, pitch:F32, roll:F32):Matrix<F32> {
    return Matrix.ofArray(4, 4, [
      ((MathF32Builtin.cos(yaw) : hl.F32) * (MathF32Builtin.cos(roll) : hl.F32) + (MathF32Builtin.sin(yaw) : hl.F32) * (MathF32Builtin.sin(pitch) : hl.F32) * (MathF32Builtin.sin(roll) : hl.F32) : F32),
      ((MathF32Builtin.sin(roll) : hl.F32) * (MathF32Builtin.cos(pitch) : hl.F32) : F32),
      (-(MathF32Builtin.sin(yaw) : hl.F32) * (MathF32Builtin.cos(roll) : hl.F32) + (MathF32Builtin.cos(yaw) : hl.F32) * (MathF32Builtin.sin(pitch) : hl.F32) * (MathF32Builtin.sin(roll) : hl.F32) : F32),
      (mathLiteralF32(0.0) : hl.F32),
      (-(MathF32Builtin.cos(yaw) : hl.F32) * (MathF32Builtin.sin(roll) : hl.F32) + (MathF32Builtin.sin(yaw) : hl.F32) * (MathF32Builtin.sin(pitch) : hl.F32) * (MathF32Builtin.cos(roll) : hl.F32) : F32),
      ((MathF32Builtin.cos(roll) : hl.F32) * (MathF32Builtin.cos(pitch) : hl.F32) : F32),
      ((MathF32Builtin.sin(roll) : hl.F32) * (MathF32Builtin.sin(yaw) : hl.F32) + (MathF32Builtin.cos(yaw) : hl.F32) * (MathF32Builtin.sin(pitch) : hl.F32) * (MathF32Builtin.cos(roll) : hl.F32) : F32),
      (mathLiteralF32(0.0) : hl.F32),
      ((MathF32Builtin.sin(yaw) : hl.F32) * (MathF32Builtin.cos(pitch) : hl.F32) : F32),
      (-(MathF32Builtin.sin(pitch) : hl.F32) : F32),
      ((MathF32Builtin.cos(yaw) : hl.F32) * (MathF32Builtin.cos(pitch) : hl.F32) : F32),
      (mathLiteralF32(0.0) : hl.F32),
      (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(0.0) : hl.F32), (mathLiteralF32(1.0) : hl.F32)
    ]);
  }

  @:qdFunc
  public static function rotation3dF32(angleX:F32, angleY:F32, angleZ:F32):Matrix<F32> {
    return rotYawPitchRollF32(angleZ, angleX, angleY);
  }
}

/** F32 signatures for calls that the kernel frontend lowers as math intrinsics. */
private class MathF32Builtin {
  public static function select(condition:Bool, ifTrue:F32, ifFalse:F32):F32 {
    throw "Quadrants MathF32Builtin.select is a kernel-only intrinsic";
  }

  public static function rawDiv(lhs:F32, rhs:F32):F32 {
    throw "Quadrants MathF32Builtin.rawDiv is a kernel-only intrinsic";
  }

  public static function min(lhs:F32, rhs:F32):F32 {
    throw "Quadrants MathF32Builtin.min is a kernel-only intrinsic";
  }

  public static function max(lhs:F32, rhs:F32):F32 {
    throw "Quadrants MathF32Builtin.max is a kernel-only intrinsic";
  }

  public static function floor(value:F32):F32 {
    throw "Quadrants MathF32Builtin.floor is a kernel-only intrinsic";
  }

  public static function log(value:F32):F32 {
    throw "Quadrants MathF32Builtin.log is a kernel-only intrinsic";
  }

  public static function sqrt(value:F32):F32 {
    throw "Quadrants MathF32Builtin.sqrt is a kernel-only intrinsic";
  }

  public static function cos(value:F32):F32 {
    throw "Quadrants MathF32Builtin.cos is a kernel-only intrinsic";
  }

  public static function sin(value:F32):F32 {
    throw "Quadrants MathF32Builtin.sin is a kernel-only intrinsic";
  }
}
