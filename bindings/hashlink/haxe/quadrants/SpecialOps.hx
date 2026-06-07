package quadrants;

import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

final class FrexpF32 {
  public final significand:F32;
  public final exponent:I32;

  public inline function new(significand:F32, exponent:I32) {
    this.significand = significand;
    this.exponent = exponent;
  }
}

final class FrexpF64 {
  public final significand:F64;
  public final exponent:I32;

  public inline function new(significand:F64, exponent:I32) {
    this.significand = significand;
    this.exponent = exponent;
  }
}

class SpecialOps {
  public static function randnF32():F32 {
    throw "Quadrants SpecialOps.randnF32 is a kernel-only construct";
  }

  public static function randnF64():F64 {
    throw "Quadrants SpecialOps.randnF64 is a kernel-only construct";
  }

  public static function fnsU32(mask:U32, base:U32, offset:I32):U32 {
    throw "Quadrants SpecialOps.fnsU32 is a kernel-only construct";
  }

  public static function rawDiv<T>(lhs:T, rhs:T):T {
    throw "Quadrants SpecialOps.rawDiv is a kernel-only construct";
  }

  public static function rawMod<T>(lhs:T, rhs:T):T {
    throw "Quadrants SpecialOps.rawMod is a kernel-only construct";
  }

  public static function frexpF32(value:F32):FrexpF32 {
    throw "Quadrants SpecialOps.frexpF32 is a kernel-only construct";
  }

  public static function frexpF64(value:F64):FrexpF64 {
    throw "Quadrants SpecialOps.frexpF64 is a kernel-only construct";
  }

  public static function volatileLoad<T>(value:T):T {
    throw "Quadrants SpecialOps.volatileLoad is a kernel-only construct";
  }
}
