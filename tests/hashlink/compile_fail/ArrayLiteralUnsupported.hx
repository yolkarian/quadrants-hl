// EXPECT_ERROR: Unsupported Quadrants HashLink kernel expression
import quadrants.Context;
import quadrants.Kernel;

class ArrayLiteralUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = [1, 2];
    });
  }
}
