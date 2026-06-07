package quadrants.quant;

import quadrants.Types.DType;

class QuantStorageSpec<T> {
  public final kind:QuantKind;
  public final bits:Int;
  public final signed:QuantSignedness;
  public final storageDType:DType;
  public final computeDType:DType;
  public final fractionalBits:Int;
  public final exponentBits:Int;
  public final fractionBits:Int;
  public final scale:Float;
  public final offset:Float;

  public function new(kind:QuantKind,
      bits:Int,
      signed:QuantSignedness,
      storageDType:DType,
      computeDType:DType,
      fractionalBits:Int = 0,
      exponentBits:Int = 0,
      fractionBits:Int = 0,
      scale:Float = 1.0,
      offset:Float = 0.0) {
    if (bits <= 0 || bits > 64) {
      throw "Quadrants quant bit width must be in 1...64";
    }
    if (fractionalBits < 0 || fractionalBits >= bits) {
      throw "Quadrants quant fractional bits must be within storage bit width";
    }
    if (exponentBits < 0 || exponentBits > 8) {
      throw "Quadrants quant exponent bits must be in 0...8";
    }
    if (fractionBits < 0 || fractionBits > 23) {
      throw "Quadrants quant fraction bits must be in 0...23";
    }
    if (scale <= 0.0) {
      throw "Quadrants quant fixed scale must be positive";
    }
    this.kind = kind;
    this.bits = bits;
    this.signed = signed;
    this.storageDType = storageDType;
    this.computeDType = computeDType;
    this.fractionalBits = fractionalBits;
    this.exponentBits = exponentBits;
    this.fractionBits = fractionBits;
    this.scale = scale;
    this.offset = offset;
  }
}
