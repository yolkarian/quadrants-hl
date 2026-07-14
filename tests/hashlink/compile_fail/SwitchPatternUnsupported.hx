// EXPECT_ERROR: Unsupported Quadrants HashLink switch pattern
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class SwitchPatternUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
      switch (a[0]) {
        case value if (value > 0):
          out[0] = 1;
        default:
          out[0] = 0;
      }
    });
  }
}
