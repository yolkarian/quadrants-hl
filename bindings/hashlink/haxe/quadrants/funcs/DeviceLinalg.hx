package quadrants.funcs;

class DeviceLinalg {
  @:qdFunc
  public static function symEig2Large(a00:Float, a01:Float, a11:Float):Float {
    return 0.5 * (a00 + a11) + Math.sqrt(0.25 * (a00 - a11) * (a00 - a11) + a01 * a01);
  }

  @:qdFunc
  public static function symEig2Small(a00:Float, a01:Float, a11:Float):Float {
    return 0.5 * (a00 + a11) - Math.sqrt(0.25 * (a00 - a11) * (a00 - a11) + a01 * a01);
  }

  @:qdFunc
  public static function eig2Large(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    return 0.5 * ((a00 + a11) + Math.sqrt((a00 + a11) * (a00 + a11) - 4.0 * (a00 * a11 - a01 * a10)));
  }

  @:qdFunc
  public static function eig2Small(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    return 0.5 * ((a00 + a11) - Math.sqrt((a00 + a11) * (a00 + a11) - 4.0 * (a00 * a11 - a01 * a10)));
  }

  @:qdFunc
  public static function svd2Sigma0(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    var c00 = a00 * a00 + a10 * a10;
    var c01 = a00 * a01 + a10 * a11;
    var c11 = a01 * a01 + a11 * a11;
    return Math.sqrt(Math.max(0.0, symEig2Large(c00, c01, c11)));
  }

  @:qdFunc
  public static function svd2Sigma1(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    var c00 = a00 * a00 + a10 * a10;
    var c01 = a00 * a01 + a10 * a11;
    var c11 = a01 * a01 + a11 * a11;
    return Math.sqrt(Math.max(0.0, symEig2Small(c00, c01, c11)));
  }

  @:qdFunc
  public static function polar2R00(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    return (a00 + a11) / Math.sqrt((a00 + a11) * (a00 + a11) + (a10 - a01) * (a10 - a01));
  }

  @:qdFunc
  public static function polar2R01(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    return (a01 - a10) / Math.sqrt((a00 + a11) * (a00 + a11) + (a10 - a01) * (a10 - a01));
  }

  @:qdFunc
  public static function polar2R10(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    return (a10 - a01) / Math.sqrt((a00 + a11) * (a00 + a11) + (a10 - a01) * (a10 - a01));
  }

  @:qdFunc
  public static function polar2R11(a00:Float, a01:Float, a10:Float, a11:Float):Float {
    return (a00 + a11) / Math.sqrt((a00 + a11) * (a00 + a11) + (a10 - a01) * (a10 - a01));
  }

  @:qdFunc
  public static function solve2X(a00:Float, a01:Float, a10:Float, a11:Float, b0:Float, b1:Float):Float {
    return (a11 * b0 - a01 * b1) / (a00 * a11 - a01 * a10);
  }

  @:qdFunc
  public static function solve2Y(a00:Float, a01:Float, a10:Float, a11:Float, b0:Float, b1:Float):Float {
    return (a00 * b1 - a10 * b0) / (a00 * a11 - a01 * a10);
  }

  @:qdFunc
  public static function solve3X(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float, b0:Float, b1:Float, b2:Float):Float {
    return ((a11 * a22 - a12 * a21) * b0 + (a02 * a21 - a01 * a22) * b1 + (a01 * a12 - a02 * a11) * b2) /
      det3(a00, a01, a02, a10, a11, a12, a20, a21, a22);
  }

  @:qdFunc
  public static function solve3Y(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float, b0:Float, b1:Float, b2:Float):Float {
    return ((a12 * a20 - a10 * a22) * b0 + (a00 * a22 - a02 * a20) * b1 + (a02 * a10 - a00 * a12) * b2) /
      det3(a00, a01, a02, a10, a11, a12, a20, a21, a22);
  }

  @:qdFunc
  public static function solve3Z(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float, b0:Float, b1:Float, b2:Float):Float {
    return ((a10 * a21 - a11 * a20) * b0 + (a01 * a20 - a00 * a21) * b1 + (a00 * a11 - a01 * a10) * b2) /
      det3(a00, a01, a02, a10, a11, a12, a20, a21, a22);
  }

  @:qdFunc
  public static function det3(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float):Float {
    return a00 * (a11 * a22 - a12 * a21) - a01 * (a10 * a22 - a12 * a20) + a02 * (a10 * a21 - a11 * a20);
  }
}
