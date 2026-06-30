// EXPECT_ERROR: Quadrants tuple return must contain at least one value
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class ReturnValueUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      return [];
    });
  }
}
