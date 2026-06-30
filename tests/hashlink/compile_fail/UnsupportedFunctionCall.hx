// EXPECT_ERROR: Unsupported Quadrants HashLink function call hypot
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class UnsupportedFunctionCall {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out[0] = hypot(3, 4);
    });
  }
}
