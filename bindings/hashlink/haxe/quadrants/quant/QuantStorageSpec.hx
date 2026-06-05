package quadrants.quant;

import quadrants.Types.DType;

class QuantStorageSpec<T> {
  public final bits:QuantBits;
  public final signed:QuantSignedness;
  public final computeDType:DType;
  public final fractionalBits:Int;

  public function new(bits:QuantBits, signed:QuantSignedness, computeDType:DType, fractionalBits:Int) {
    var bitCount:Int = bits;
    if (fractionalBits < 0 || fractionalBits >= bitCount) {
      throw "Quadrants quant fractional bits must be within storage bit width";
    }
    this.bits = bits;
    this.signed = signed;
    this.computeDType = computeDType;
    this.fractionalBits = fractionalBits;
  }
}
