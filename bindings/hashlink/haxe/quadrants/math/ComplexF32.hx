package quadrants.math;

import quadrants.Vector;
import quadrants.Types.F32;

/** Kernel-local complex arithmetic using a two-lane F32 vector [real, imaginary]. */
class ComplexF32 {
  @:qdFunc
  public static function cmulF32(z1:Vector<F32>, z2:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((z1[0] : Float) * (z2[0] : Float) - (z1[1] : Float) * (z2[1] : Float) : F32),
      ((z1[0] : Float) * (z2[1] : Float) + (z2[0] : Float) * (z1[1] : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function cconjF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      z[0],
      (-(z[1] : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function cdivF32(z1:Vector<F32>, z2:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      (((z1[0] : Float) * (z2[0] : Float) + (z1[1] : Float) * (z2[1] : Float)) / ((z2[0] : Float) * (z2[0] : Float) + (z2[1] : Float) * (z2[1] : Float)) : F32),
      ((-(z1[0] : Float) * (z2[1] : Float) + (z2[0] : Float) * (z1[1] : Float)) / ((z2[0] : Float) * (z2[0] : Float) + (z2[1] : Float) * (z2[1] : Float)) : F32)
    ]);
  }

  @:qdFunc
  public static function csqrtF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      (Math.sqrt(Math.sqrt((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float))) * Math.cos(Math.atan2((z[1] : Float), (z[0] : Float)) / 2.0) : F32),
      (Math.sqrt(Math.sqrt((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float))) * Math.sin(Math.atan2((z[1] : Float), (z[0] : Float)) / 2.0) : F32)
    ]);
  }

  @:qdFunc
  public static function cinvF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((z[0] : Float) / ((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float)) : F32),
      (-(z[1] : Float) / ((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float)) : F32)
    ]);
  }

  @:qdFunc
  private static function cpowComponentF32(z:Vector<F32>, exponent:Int, component:Int):F32 {
    var result:F32 = (0.0 : F32);
    if ((z[0] : Float) != 0.0 || (z[1] : Float) != 0.0) {
      var power:Int = exponent;
      var baseReal:F32 = z[0];
      var baseImag:F32 = z[1];
      var appendBase:Bool = false;
      if (power < 0) {
        var denominator:F32 = ((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float) : F32);
        baseReal = ((z[0] : Float) / (denominator : Float) : F32);
        baseImag = (-(z[1] : Float) / (denominator : Float) : F32);
        if (power == (-2147483647 - 1)) {
          power = 2147483647;
          appendBase = true;
        } else {
          power = -power;
        }
      }
      var productReal:F32 = (1.0 : F32);
      var productImag:F32 = (0.0 : F32);
      while (power > 0) {
        if ((power & 1) != 0) {
          var nextReal:F32 = ((productReal : Float) * (baseReal : Float) - (productImag : Float) * (baseImag : Float) : F32);
          var nextImag:F32 = ((productReal : Float) * (baseImag : Float) + (productImag : Float) * (baseReal : Float) : F32);
          productReal = nextReal;
          productImag = nextImag;
        }
        var squaredReal:F32 = ((baseReal : Float) * (baseReal : Float) - (baseImag : Float) * (baseImag : Float) : F32);
        var squaredImag:F32 = (2.0 * (baseReal : Float) * (baseImag : Float) : F32);
        baseReal = squaredReal;
        baseImag = squaredImag;
        power = power >> 1;
      }
      if (appendBase) {
        var finalReal:F32 = ((productReal : Float) * (baseReal : Float) - (productImag : Float) * (baseImag : Float) : F32);
        var finalImag:F32 = ((productReal : Float) * (baseImag : Float) + (productImag : Float) * (baseReal : Float) : F32);
        productReal = finalReal;
        productImag = finalImag;
      }
      if (component == 0) result = productReal;
      if (component == 1) result = productImag;
    }
    return result;
  }

  @:qdFunc
  public static function cpowF32(z:Vector<F32>, exponent:Int):Vector<F32> {
    return Vector.ofArray([
      cpowComponentF32(z, exponent, 0),
      cpowComponentF32(z, exponent, 1)
    ]);
  }

  @:qdFunc
  public static function cexpF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      (Math.exp(z[0] : Float) * Math.cos(z[1] : Float) : F32),
      (Math.exp(z[0] : Float) * Math.sin(z[1] : Float) : F32)
    ]);
  }

  @:qdFunc
  public static function clogF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      (Math.log((z[0] : Float) * (z[0] : Float) + (z[1] : Float) * (z[1] : Float)) / 2.0 : F32),
      (Math.atan2((z[1] : Float), (z[0] : Float)) : F32)
    ]);
  }
}
