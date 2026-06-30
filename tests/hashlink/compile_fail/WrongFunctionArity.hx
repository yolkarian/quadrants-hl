// EXPECT_ERROR: Quadrants HashLink function sqrt expects 1 argument(s)
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class WrongFunctionArity {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out[0] = sqrt(4, 5);
    });
  }
}
