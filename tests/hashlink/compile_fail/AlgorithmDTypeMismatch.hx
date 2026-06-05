// EXPECT_ERROR: quadrants.F32 should be quadrants.I32
import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.algorithms.Reduce;

class AlgorithmDTypeMismatch {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var input = new Tensor<I32>(ctx, [1]);
    var output = new Tensor<F32>(ctx, [1]);
    Reduce.deviceReduceAdd(input, output);
  }
}
