package quadrants.quant;

import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

class Quant {
  public static function intI32(bits:QuantBits, signed:QuantSignedness):QuantInt<I32, I32> {
    return new QuantInt(bits, signed, DType.I32, DType.I32);
  }

  public static function fixedF32(bits:QuantBits, signed:QuantSignedness, fractionalBits:Int):QuantFixed<I32, F32> {
    var scale = 1.0 / Math.pow(2.0, fractionalBits);
    return new QuantFixed(bits, signed, DType.I32, DType.F32, fractionalBits, scale);
  }

  public static function floatF32(exponentBits:Int, fractionBits:Int, signed:QuantSignedness):QuantFloat<I32, F32> {
    return new QuantFloat(exponentBits, fractionBits, signed, DType.I32, DType.F32);
  }
}
