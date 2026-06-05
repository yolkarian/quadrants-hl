// EXPECT_ERROR: Field_I32 should be quadrants.TensorArg
import quadrants.Context;
import quadrants.Field;
import quadrants.VectorNdarray;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class CompoundStorageKindMismatch {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var storage = new Field<I32>(ctx, [4]);
    var values = new VectorNdarray<I32>(storage, 2);
  }
}
