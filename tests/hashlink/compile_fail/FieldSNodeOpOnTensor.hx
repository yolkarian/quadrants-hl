// EXPECT_ERROR: Quadrants Tensor parameter tensor cannot be used as a Field SNode
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class FieldSNodeOpOnTensor {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (tensor:Tensor<I32>) -> {
      tensor.activate(0);
    });
  }
}
