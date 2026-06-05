// EXPECT_ERROR: Quadrants CompilerHints.assumeInRange high bound must be greater than low bound
import quadrants.CompilerHints;
import quadrants.Context;
import quadrants.Kernel;

class AssumeInRangeInvalidBounds {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = CompilerHints.assumeInRange(0, 0, 4, 4);
    });
  }
}
