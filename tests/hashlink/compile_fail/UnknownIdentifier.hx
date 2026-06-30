// EXPECT_ERROR: Unknown Quadrants kernel identifier missing
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class UnknownIdentifier {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out[0] = missing;
    });
  }
}
