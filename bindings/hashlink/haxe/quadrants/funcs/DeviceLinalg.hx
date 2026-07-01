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

  @:qdFunc
  public static function symEig3Value(a00:Float, a01:Float, a02:Float, a11:Float, a12:Float, a22:Float, which:Int):Float {
    var d0 = a00;
    var d1 = a11;
    var d2 = a22;
    var p1 = a01 * a01 + a02 * a02 + a12 * a12;
    if (p1 > 1.0e-12) {
      var q = (a00 + a11 + a22) / 3.0;
      var b00 = a00 - q;
      var b11 = a11 - q;
      var b22 = a22 - q;
      var p2 = b00 * b00 + b11 * b11 + b22 * b22 + 2.0 * p1;
      var p = Math.sqrt(p2 / 6.0);
      var invP = 1.0 / p;
      var c00 = b00 * invP;
      var c01 = a01 * invP;
      var c02 = a02 * invP;
      var c11 = b11 * invP;
      var c12 = a12 * invP;
      var c22 = b22 * invP;
      var r = 0.5 * det3(c00, c01, c02, c01, c11, c12, c02, c12, c22);
      r = Math.max(-1.0, Math.min(1.0, r));
      var phi = Math.acos(r) / 3.0;
      d0 = q + 2.0 * p * Math.cos(phi);
      d2 = q + 2.0 * p * Math.cos(phi + 2.0943951023931953);
      d1 = 3.0 * q - d0 - d2;
    }
    if (d1 > d0) {
      var t = d0;
      d0 = d1;
      d1 = t;
    }
    if (d2 > d0) {
      var t = d0;
      d0 = d2;
      d2 = t;
    }
    if (d2 > d1) {
      var t = d1;
      d1 = d2;
      d2 = t;
    }
    var result = d2;
    if (which == 0) result = d0;
    if (which == 1) result = d1;
    return result;
  }

  @:qdFunc
  public static function svd3Sigma(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float, which:Int):Float {
    var m00 = a00 * a00 + a10 * a10 + a20 * a20;
    var m01 = a00 * a01 + a10 * a11 + a20 * a21;
    var m02 = a00 * a02 + a10 * a12 + a20 * a22;
    var m11 = a01 * a01 + a11 * a11 + a21 * a21;
    var m12 = a01 * a02 + a11 * a12 + a21 * a22;
    var m22 = a02 * a02 + a12 * a12 + a22 * a22;
    var d0 = m00;
    var d1 = m11;
    var d2 = m22;
    var p1 = m01 * m01 + m02 * m02 + m12 * m12;
    if (p1 > 1.0e-12) {
      var q = (m00 + m11 + m22) / 3.0;
      var b00 = m00 - q;
      var b11 = m11 - q;
      var b22 = m22 - q;
      var p2 = b00 * b00 + b11 * b11 + b22 * b22 + 2.0 * p1;
      var p = Math.sqrt(p2 / 6.0);
      var invP = 1.0 / p;
      var c00 = b00 * invP;
      var c01 = m01 * invP;
      var c02 = m02 * invP;
      var c11 = b11 * invP;
      var c12 = m12 * invP;
      var c22 = b22 * invP;
      var r = 0.5 * det3(c00, c01, c02, c01, c11, c12, c02, c12, c22);
      r = Math.max(-1.0, Math.min(1.0, r));
      var phi = Math.acos(r) / 3.0;
      d0 = q + 2.0 * p * Math.cos(phi);
      d2 = q + 2.0 * p * Math.cos(phi + 2.0943951023931953);
      d1 = 3.0 * q - d0 - d2;
    }
    if (d1 > d0) {
      var t = d0;
      d0 = d1;
      d1 = t;
    }
    if (d2 > d0) {
      var t = d0;
      d0 = d2;
      d2 = t;
    }
    if (d2 > d1) {
      var t = d1;
      d1 = d2;
      d2 = t;
    }
    var sigma = Math.sqrt(Math.max(0.0, d2));
    if (which == 0) sigma = Math.sqrt(Math.max(0.0, d0));
    if (which == 1) sigma = Math.sqrt(Math.max(0.0, d1));
    return sigma;
  }

  @:qdFunc
  public static function polar3R(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float, component:Int):Float {
    var c0n = Math.sqrt(a00 * a00 + a10 * a10 + a20 * a20);
    var q00 = a00 / c0n;
    var q10 = a10 / c0n;
    var q20 = a20 / c0n;
    var dot = q00 * a01 + q10 * a11 + q20 * a21;
    var u01 = a01 - dot * q00;
    var u11 = a11 - dot * q10;
    var u21 = a21 - dot * q20;
    var c1n = Math.sqrt(u01 * u01 + u11 * u11 + u21 * u21);
    var q01 = u01 / c1n;
    var q11 = u11 / c1n;
    var q21 = u21 / c1n;
    var q02 = q10 * q21 - q20 * q11;
    var q12 = q20 * q01 - q00 * q21;
    var q22 = q00 * q11 - q10 * q01;
    var result = q22;
    if (component == 0) result = q00;
    if (component == 1) result = q01;
    if (component == 2) result = q02;
    if (component == 3) result = q10;
    if (component == 4) result = q11;
    if (component == 5) result = q12;
    if (component == 6) result = q20;
    if (component == 7) result = q21;
    return result;
  }

  @:qdFunc
  public static function makeSpd3(a00:Float, a01:Float, a02:Float, a10:Float, a11:Float, a12:Float, a20:Float, a21:Float, a22:Float, component:Int):Float {
    var s00 = a00;
    var s01 = 0.5 * (a01 + a10);
    var s02 = 0.5 * (a02 + a20);
    var s11 = a11;
    var s12 = 0.5 * (a12 + a21);
    var s22 = a22;
    var lower0 = s00 - Math.abs(s01) - Math.abs(s02);
    var lower1 = s11 - Math.abs(s01) - Math.abs(s12);
    var lower2 = s22 - Math.abs(s02) - Math.abs(s12);
    var lower = Math.min(lower0, Math.min(lower1, lower2));
    var shift = Math.max(0.0, 1.0e-10 - lower);
    var result = s22 + shift;
    if (component == 0) result = s00 + shift;
    if (component == 1) result = s01;
    if (component == 2) result = s02;
    if (component == 3) result = s01;
    if (component == 4) result = s11 + shift;
    if (component == 5) result = s12;
    if (component == 6) result = s02;
    if (component == 7) result = s12;
    return result;
  }
}
