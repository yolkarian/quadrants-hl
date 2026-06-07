package quadrants.quant;

import quadrants.Types.DType;

class QuantFloat<Storage, Compute> extends QuantStorageSpec<Compute> {
  public function new(exponentBits:Int,
      fractionBits:Int,
      signed:QuantSignedness,
      storageDType:DType,
      computeDType:DType) {
    super(QuantKind.FloatStorage, (signed ? 1 : 0) + exponentBits + fractionBits, signed, storageDType, computeDType, 0, exponentBits, fractionBits);
    if (exponentBits <= 0) {
      throw "Quadrants quant float exponent bits must be positive";
    }
    if (fractionBits <= 0) {
      throw "Quadrants quant float fraction bits must be positive";
    }
  }
}
