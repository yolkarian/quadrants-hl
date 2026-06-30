// EXPECT_ERROR: Quadrants HashLink does not support do-while loops
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class UnsupportedDoWhile {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var i = 0;
      do {
        out[i] = i;
        i = i + 1;
      } while (i < 4);
    });
  }
}
