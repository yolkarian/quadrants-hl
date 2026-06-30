// EXPECT_ERROR: Unsupported Quadrants HashLink unary operator
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class UnsupportedUnaryOperator {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var i = 0;
      out[0] = ++i;
    });
  }
}
