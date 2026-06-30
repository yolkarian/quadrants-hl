// EXPECT_ERROR: Quadrants HashLink supports one local variable declaration per statement
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class MultipleLocalVarDecl {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var a = 1, b = 2;
      out[0] = a + b;
    });
  }
}
