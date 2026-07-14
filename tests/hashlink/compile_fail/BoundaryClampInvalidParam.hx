// EXPECT_ERROR: Quadrants boundaryClamp requires a Tensor kernel parameter
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class BoundaryClampInvalidParam {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (n:Int, out:Tensor<I32>) -> {
      out[0] = n;
    }, {boundaryClamp: ["n"]});
  }
}
