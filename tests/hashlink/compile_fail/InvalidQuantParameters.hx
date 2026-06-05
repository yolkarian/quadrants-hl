// EXPECT_ERROR: Int should be quadrants.quant.QuantBits
import quadrants.quant.Quant;
import quadrants.quant.QuantSignedness;

class InvalidQuantParameters {
  static function main():Void {
    Quant.fixedF32(7, QuantSignedness.Signed, 4);
  }
}
