package quadrants.math;

import quadrants.Vector;
import quadrants.Types.F32;

/** Kernel-local complex arithmetic using a two-lane F32 vector [real, imaginary]. */
class ComplexF32 {
  @:qdFunc
  public static function cmulF32(z1:Vector<F32>, z2:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((z1[0] : hl.F32) * (z2[0] : hl.F32) - (z1[1] : hl.F32) * (z2[1] : hl.F32) : F32),
      ((z1[0] : hl.F32) * (z2[1] : hl.F32) + (z2[0] : hl.F32) * (z1[1] : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function cconjF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      z[0],
      (-(z[1] : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function cdivF32(z1:Vector<F32>, z2:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ComplexF32Builtin.rawDiv(
        (z1[0] : hl.F32) * (z2[0] : hl.F32) + (z1[1] : hl.F32) * (z2[1] : hl.F32),
        (z2[0] : hl.F32) * (z2[0] : hl.F32) + (z2[1] : hl.F32) * (z2[1] : hl.F32)),
      ComplexF32Builtin.rawDiv(
        -(z1[0] : hl.F32) * (z2[1] : hl.F32) + (z2[0] : hl.F32) * (z1[1] : hl.F32),
        (z2[0] : hl.F32) * (z2[0] : hl.F32) + (z2[1] : hl.F32) * (z2[1] : hl.F32))
    ]);
  }

  @:qdFunc
  public static function csqrtF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ((ComplexF32Builtin.sqrt(ComplexF32Builtin.sqrt((((z[0] : hl.F32) * (z[0] : hl.F32) + (z[1] : hl.F32) * (z[1] : hl.F32)) : F32))) : hl.F32)
        * (ComplexF32Builtin.cos(ComplexF32Builtin.rawDiv(
          ComplexF32Builtin.atan2(z[1], z[0]),
          (z[0] : hl.F32) - (z[0] : hl.F32) + 2)) : hl.F32) : F32),
      ((ComplexF32Builtin.sqrt(ComplexF32Builtin.sqrt((((z[0] : hl.F32) * (z[0] : hl.F32) + (z[1] : hl.F32) * (z[1] : hl.F32)) : F32))) : hl.F32)
        * (ComplexF32Builtin.sin(ComplexF32Builtin.rawDiv(
          ComplexF32Builtin.atan2(z[1], z[0]),
          (z[0] : hl.F32) - (z[0] : hl.F32) + 2)) : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function cinvF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ComplexF32Builtin.rawDiv(
        z[0],
        (z[0] : hl.F32) * (z[0] : hl.F32) + (z[1] : hl.F32) * (z[1] : hl.F32)),
      ComplexF32Builtin.rawDiv(
        -(z[1] : hl.F32),
        (z[0] : hl.F32) * (z[0] : hl.F32) + (z[1] : hl.F32) * (z[1] : hl.F32))
    ]);
  }

  @:qdFunc
  private static function cpowComponentF32(z:Vector<F32>, exponent:Int, component:Int):F32 {
    var result:F32 = (0.0 : F32);
    if ((z[0] : hl.F32) != 0 || (z[1] : hl.F32) != 0) {
      var power:Int = exponent;
      var baseReal:F32 = z[0];
      var baseImag:F32 = z[1];
      var appendBase:Bool = false;
      if (power < 0) {
        var denominator:F32 = ((z[0] : hl.F32) * (z[0] : hl.F32) + (z[1] : hl.F32) * (z[1] : hl.F32) : F32);
        baseReal = ComplexF32Builtin.rawDiv(z[0], denominator);
        baseImag = ComplexF32Builtin.rawDiv(-(z[1] : hl.F32), denominator);
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
          var nextReal:F32 = ((productReal : hl.F32) * (baseReal : hl.F32) - (productImag : hl.F32) * (baseImag : hl.F32) : F32);
          var nextImag:F32 = ((productReal : hl.F32) * (baseImag : hl.F32) + (productImag : hl.F32) * (baseReal : hl.F32) : F32);
          productReal = nextReal;
          productImag = nextImag;
        }
        var squaredReal:F32 = ((baseReal : hl.F32) * (baseReal : hl.F32) - (baseImag : hl.F32) * (baseImag : hl.F32) : F32);
        var squaredImag:F32 = (2 * (baseReal : hl.F32) * (baseImag : hl.F32) : F32);
        baseReal = squaredReal;
        baseImag = squaredImag;
        power = power >> 1;
      }
      if (appendBase) {
        var finalReal:F32 = ((productReal : hl.F32) * (baseReal : hl.F32) - (productImag : hl.F32) * (baseImag : hl.F32) : F32);
        var finalImag:F32 = ((productReal : hl.F32) * (baseImag : hl.F32) + (productImag : hl.F32) * (baseReal : hl.F32) : F32);
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
      ((ComplexF32Builtin.exp(z[0]) : hl.F32) * (ComplexF32Builtin.cos(z[1]) : hl.F32) : F32),
      ((ComplexF32Builtin.exp(z[0]) : hl.F32) * (ComplexF32Builtin.sin(z[1]) : hl.F32) : F32)
    ]);
  }

  @:qdFunc
  public static function clogF32(z:Vector<F32>):Vector<F32> {
    return Vector.ofArray([
      ComplexF32Builtin.rawDiv(
        ComplexF32Builtin.log((((z[0] : hl.F32) * (z[0] : hl.F32) + (z[1] : hl.F32) * (z[1] : hl.F32)) : F32)),
        (z[0] : hl.F32) - (z[0] : hl.F32) + 2),
      ComplexF32Builtin.atan2(z[1], z[0])
    ]);
  }
}

/** F32 signatures for calls that the kernel frontend lowers as math intrinsics. */
private class ComplexF32Builtin {
  public static function rawDiv(lhs:F32, rhs:F32):F32 {
    throw "Quadrants ComplexF32Builtin.rawDiv is a kernel-only intrinsic";
  }

  public static function sqrt(value:F32):F32 {
    throw "Quadrants ComplexF32Builtin.sqrt is a kernel-only intrinsic";
  }

  public static function cos(value:F32):F32 {
    throw "Quadrants ComplexF32Builtin.cos is a kernel-only intrinsic";
  }

  public static function sin(value:F32):F32 {
    throw "Quadrants ComplexF32Builtin.sin is a kernel-only intrinsic";
  }

  public static function atan2(y:F32, x:F32):F32 {
    throw "Quadrants ComplexF32Builtin.atan2 is a kernel-only intrinsic";
  }

  public static function exp(value:F32):F32 {
    throw "Quadrants ComplexF32Builtin.exp is a kernel-only intrinsic";
  }

  public static function log(value:F32):F32 {
    throw "Quadrants ComplexF32Builtin.log is a kernel-only intrinsic";
  }
}
