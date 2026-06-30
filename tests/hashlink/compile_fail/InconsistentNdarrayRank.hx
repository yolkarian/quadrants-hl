// EXPECT_ERROR: Quadrants ndarray parameter a is used with inconsistent rank
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class InconsistentNdarrayRank {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
      out[0] = a[0] + a[0][0];
    });
  }
}
