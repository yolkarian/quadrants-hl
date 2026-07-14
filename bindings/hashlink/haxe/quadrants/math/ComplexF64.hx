package quadrants.math;

import quadrants.Vector;
import quadrants.Types.F64;

/** Kernel-local complex arithmetic using a two-lane F64 vector [real, imaginary]. */
class ComplexF64 {
  @:qdFunc
  public static function cmulF64(z1:Vector<F64>, z2:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((z1[0] : Float) * (z2[0] : Float) - (z1[1] : Float) * (z2[1] : Float)),
      ((z1[0] : Float) * (z2[1] : Float) + (z2[0] : Float) * (z1[1] : Float))
    ]);
  }

  @:qdFunc
  public static function cconjF64(z:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      z[0],
      (-(z[1] : Float))
    ]);
  }

  @:qdFunc
  public static function cdivF64(z1:Vector<F64>, z2:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      (((z1[0] : Float) * (z2[0] : Float) + (z1[1] : Float) * (z2[1] : Float)) / ((z2[0] : Float) * (z2[0] : Float) + (z2[1] : Float) * (z2[1] : Float))),
      ((-(z1[0] : Float) * (z2[1] : Float) + (z2[0] : Float) * (z1[1] : Float)) / ((z2[0] : Float) * (z2[0] : Float) + (z2[1] : Float) * (z2[1] : Float)))
    ]);
  }

  @:qdFunc
  public static function csqrtF64(z:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      (Math.sqrt(Math.sqrt((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float))) * Math.cos(Math.atan2((z[1] : Float), (z[0] : Float)) / 2.0)),
      (Math.sqrt(Math.sqrt((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float))) * Math.sin(Math.atan2((z[1] : Float), (z[0] : Float)) / 2.0))
    ]);
  }

  @:qdFunc
  public static function cinvF64(z:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      ((z[0] : Float) / ((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float))),
      (-(z[1] : Float) / ((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float)))
    ]);
  }

  @:qdFunc
  private static function cpowComponentF64(z:Vector<F64>, exponent:Int, component:Int):F64 {
    var result:F64 = (0.0);
    if ((z[0] : Float) != 0.0 || (z[1] : Float) != 0.0) {
      var power:Int = exponent;
      var baseReal:F64 = z[0];
      var baseImag:F64 = z[1];
      var appendBase:Bool = false;
      if (power < 0) {
        var denominator:F64 = ((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float));
        baseReal = ((z[0] : Float) / (denominator : Float));
        baseImag = (-(z[1] : Float) / (denominator : Float));
        if (power == (-2147483647 - 1)) {
          power = 2147483647;
          appendBase = true;
        } else {
          power = -power;
        }
      }
      var productReal:F64 = (1.0);
      var productImag:F64 = (0.0);
      while (power > 0) {
        if ((power & 1) != 0) {
          var nextReal:F64 = ((productReal : Float) * (baseReal : Float) - (productImag : Float) * (baseImag : Float));
          var nextImag:F64 = ((productReal : Float) * (baseImag : Float) + (productImag : Float) * (baseReal : Float));
          productReal = nextReal;
          productImag = nextImag;
        }
        var squaredReal:F64 = ((baseReal : Float) * (baseReal : Float) - (baseImag : Float) * (baseImag : Float));
        var squaredImag:F64 = (2.0 * (baseReal : Float) * (baseImag : Float));
        baseReal = squaredReal;
        baseImag = squaredImag;
        power = power >> 1;
      }
      if (appendBase) {
        var finalReal:F64 = ((productReal : Float) * (baseReal : Float) - (productImag : Float) * (baseImag : Float));
        var finalImag:F64 = ((productReal : Float) * (baseImag : Float) + (productImag : Float) * (baseReal : Float));
        productReal = finalReal;
        productImag = finalImag;
      }
      if (component == 0) result = productReal;
      if (component == 1) result = productImag;
    }
    return result;
  }

  @:qdFunc
  public static function cpowF64(z:Vector<F64>, exponent:Int):Vector<F64> {
    return Vector.ofArray([
      cpowComponentF64(z, exponent, 0),
      cpowComponentF64(z, exponent, 1)
    ]);
  }

  @:qdFunc
  public static function cexpF64(z:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      (Math.exp((z[0] : Float)) * Math.cos((z[1] : Float))),
      (Math.exp((z[0] : Float)) * Math.sin((z[1] : Float)))
    ]);
  }

  @:qdFunc
  public static function clogF64(z:Vector<F64>):Vector<F64> {
    return Vector.ofArray([
      (Math.log((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float)) / 2.0),
      (Math.atan2((z[1] : Float), (z[0] : Float)))
    ]);
  }
}
