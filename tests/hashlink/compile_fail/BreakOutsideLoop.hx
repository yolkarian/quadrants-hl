// EXPECT_ERROR: Quadrants HashLink break must be inside a loop
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class BreakOutsideLoop {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      break;
    });
  }
}
