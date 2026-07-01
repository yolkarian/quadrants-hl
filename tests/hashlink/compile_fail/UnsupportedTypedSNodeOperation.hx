// EXPECT_ERROR: has no field quantArray
import quadrants.Context;
import quadrants.Types.Arch;
import quadrants.quant.QuantBits;

class UnsupportedTypedSNodeOperation {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var path = ctx.root.dense([4]).finalize();
    path.quantArray(QuantBits.Bits8);
  }
}
