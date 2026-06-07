// EXPECT_ERROR: Quadrants HashLink Tensor.scalarRead() expects no arguments
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class ScalarReadWrongArity {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (scalar:Tensor<I32>) -> {
      return scalar.scalarRead(0);
    });
  }
}
