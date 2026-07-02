package quadrants.funcs;

import quadrants.Matrix;
import quadrants.Vector;

/**
 * Kernel-side linalg facade for Matrix/Vector values.
 *
 * Include both `LinalgDevice` and `DeviceLinalg` in `Kernel.build(..., {helpers: [...]})`.
 * `DeviceLinalg` owns the scalar component kernels; this facade assembles the same component
 * helpers into kernel-local Matrix/Vector return values.
 */
class LinalgDevice {
  @:qdFunc
  public static function solve2(a:Matrix<Float>, b:Vector<Float>) {
    return Vector.ofArray([
      DeviceLinalg.solve2X(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1), b[0], b[1]),
      DeviceLinalg.solve2Y(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1), b[0], b[1])]);
  }

  @:qdFunc
  public static function eig2Values(a:Matrix<Float>) {
    return Vector.ofArray([
      DeviceLinalg.eig2Large(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1)),
      DeviceLinalg.eig2Small(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1))]);
  }

  @:qdFunc
  public static function polar2Rotation(a:Matrix<Float>) {
    return Matrix.ofArray(2, 2, [
      DeviceLinalg.polar2R00(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1)),
      DeviceLinalg.polar2R01(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1)),
      DeviceLinalg.polar2R10(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1)),
      DeviceLinalg.polar2R11(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1))]);
  }

  @:qdFunc
  public static function makeSpd2Component(a00:Float, a01:Float, a10:Float, a11:Float, component:Int):Float {
    var s01 = 0.5 * (a01 + a10);
    var lower = Math.min(a00 - Math.abs(s01), a11 - Math.abs(s01));
    var shift = Math.max(0.0, 1.0e-10 - lower);
    var result = a11 + shift;
    if (component == 0) result = a00 + shift;
    if (component == 1) result = s01;
    if (component == 2) result = s01;
    return result;
  }

  @:qdFunc
  public static function makeSpd2(a:Matrix<Float>) {
    return Matrix.ofArray(2, 2, [
      makeSpd2Component(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1), 0),
      makeSpd2Component(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1), 1),
      makeSpd2Component(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1), 2),
      makeSpd2Component(a.kernelGet(0, 0), a.kernelGet(0, 1), a.kernelGet(1, 0), a.kernelGet(1, 1), 3)]);
  }
}
