// EXPECT_ERROR: Field_I32 should be quadrants.TensorArg
import quadrants.Context;
import quadrants.Field;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.algorithms.Scan;

class AlgorithmTensorFieldMismatch {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var input = new Tensor<I32>(ctx, [1]);
    var output = new Field<I32>(ctx, [1]);
    Scan.deviceExclusiveScanAdd(input, output);
  }
}
