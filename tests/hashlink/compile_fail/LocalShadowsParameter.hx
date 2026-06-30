// EXPECT_ERROR: Quadrants local variable out shadows a kernel parameter
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class LocalShadowsParameter {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var out = 1;
    });
  }
}
