package quadrants.quant;

import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

class Quant {
  public static function intI32(bits:QuantBits, signed:QuantSignedness):QuantStorageSpec<I32> {
    return new QuantStorageSpec(bits, signed, DType.I32, 0);
  }

  public static function fixedF32(bits:QuantBits, signed:QuantSignedness, fractionalBits:Int):QuantStorageSpec<F32> {
    return new QuantStorageSpec(bits, signed, DType.F32, fractionalBits);
  }
}
