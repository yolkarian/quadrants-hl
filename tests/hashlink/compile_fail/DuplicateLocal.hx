// EXPECT_ERROR: Duplicate Quadrants local variable x
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class DuplicateLocal {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var x = 1;
      var x = 2;
      out[0] = x;
    });
  }
}
