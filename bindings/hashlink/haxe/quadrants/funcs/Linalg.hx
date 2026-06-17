package quadrants.funcs;

import quadrants.Matrix;
import quadrants.Vector;

typedef SvdResult<T> = {
  var u:Matrix<T>;
  var sigma:Vector<T>;
  var v:Matrix<T>;
}

typedef EigResult<T> = {
  var values:Vector<T>;
  var vectors:Matrix<T>;
}

class Linalg {
  public static function svd2<T>(m:Matrix<T>):SvdResult<T> {
    requireShape(m, 2, 2, "svd2");
    throw "Quadrants Linalg.svd2 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function svd3<T>(m:Matrix<T>):SvdResult<T> {
    requireShape(m, 3, 3, "svd3");
    throw "Quadrants Linalg.svd3 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function symEig2<T>(m:Matrix<T>):EigResult<T> {
    requireShape(m, 2, 2, "symEig2");
    throw "Quadrants Linalg.symEig2 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function symEig3<T>(m:Matrix<T>):EigResult<T> {
    requireShape(m, 3, 3, "symEig3");
    throw "Quadrants Linalg.symEig3 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function eig2<T>(m:Matrix<T>):EigResult<T> {
    requireShape(m, 2, 2, "eig2");
    throw "Quadrants Linalg.eig2 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function polar2<T>(m:Matrix<T>):{var u:Matrix<T>; var p:Matrix<T>;} {
    requireShape(m, 2, 2, "polar2");
    throw "Quadrants Linalg.polar2 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function polar3<T>(m:Matrix<T>):{var u:Matrix<T>; var p:Matrix<T>;} {
    requireShape(m, 3, 3, "polar3");
    throw "Quadrants Linalg.polar3 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function solve2<T>(a:Matrix<T>, b:Vector<T>):Vector<T> {
    requireShape(a, 2, 2, "solve2");
    requireVector(b, 2, "solve2");
    throw "Quadrants Linalg.solve2 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function solve3<T>(a:Matrix<T>, b:Vector<T>):Vector<T> {
    requireShape(a, 3, 3, "solve3");
    requireVector(b, 3, "solve3");
    throw "Quadrants Linalg.solve3 is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  public static function makeSpd<T>(a:Matrix<T>):Matrix<T> {
    if (a.rows != a.cols || (a.rows != 2 && a.rows != 3)) {
      throw "Quadrants Linalg.makeSpd supports only 2x2 and 3x3 matrices";
    }
    throw "Quadrants Linalg.makeSpd is a descriptor intrinsic in device kernels; host fallback is not enabled";
  }

  static function requireShape<T>(m:Matrix<T>, rows:Int, cols:Int, name:String):Void {
    if (m == null || m.rows != rows || m.cols != cols) {
      throw 'Quadrants Linalg.${name} requires a ${rows}x${cols} matrix';
    }
  }

  static function requireVector<T>(v:Vector<T>, length:Int, name:String):Void {
    if (v.length != length) {
      throw 'Quadrants Linalg.${name} requires a vector of length ${length}';
    }
  }
}
