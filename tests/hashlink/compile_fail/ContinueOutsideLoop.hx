// EXPECT_ERROR: Quadrants HashLink continue must be inside a loop
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class ContinueOutsideLoop {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      continue;
    });
  }
}
