// EXPECT_ERROR: Quadrants parameter out is used as both ndarray and scalar
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class IndirectNdarrayIndexing {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var other = out;
      other[0] = 1;
    });
  }
}
