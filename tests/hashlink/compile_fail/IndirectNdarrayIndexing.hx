// EXPECT_ERROR: Quadrants ndarray other is not a kernel parameter
import quadrants.Context;
import quadrants.Kernel;

class IndirectNdarrayIndexing {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var other = out;
      other[0] = 1;
    });
  }
}
