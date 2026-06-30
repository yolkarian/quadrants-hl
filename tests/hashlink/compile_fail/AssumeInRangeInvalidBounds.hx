// EXPECT_ERROR: Quadrants CompilerHints.assumeInRange high bound must be greater than low bound
import quadrants.CompilerHints;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class AssumeInRangeInvalidBounds {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out[0] = CompilerHints.assumeInRange(0, 0, 4, 4);
    });
  }
}
