// EXPECT_ERROR: Duplicate Quadrants kernel parameter out
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class DuplicateParameter {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>, out:Tensor<I32>) -> {
      out[0] = 1;
    });
  }
}
