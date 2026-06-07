package quadrants.quant;

import quadrants.Types.DType;

class QuantInt<Storage, Compute> extends QuantStorageSpec<Compute> {
  public function new(bits:QuantBits, signed:QuantSignedness, storageDType:DType, computeDType:DType) {
    super(QuantKind.IntStorage, bits, signed, storageDType, computeDType);
  }
}
