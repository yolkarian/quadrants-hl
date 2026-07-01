package quadrants.quant;

import quadrants.Types.DType;

class QuantFixed<Storage, Compute> extends QuantStorageSpec<Compute> {
  public function new(bits:QuantBits,
      signed:QuantSignedness,
      storageDType:DType,
      computeDType:DType,
      fractionalBits:Int,
      scale:Float) {
    super(QuantKind.Fixed, bits, signed, storageDType, computeDType, fractionalBits, 0, 0, scale);
  }
}
