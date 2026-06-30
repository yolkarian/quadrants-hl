// EXPECT_ERROR: Unsupported Quadrants HashLink kernel expression
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class ArrayLiteralUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out[0] = [1, 2];
    });
  }
}
