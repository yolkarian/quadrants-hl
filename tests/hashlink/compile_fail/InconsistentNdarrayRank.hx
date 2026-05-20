// EXPECT_ERROR: Quadrants ndarray parameter a is used with inconsistent rank
import quadrants.Context;
import quadrants.Kernel;

class InconsistentNdarrayRank {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (a, out) -> {
      out[0] = a[0] + a[0][0];
    });
  }
}
