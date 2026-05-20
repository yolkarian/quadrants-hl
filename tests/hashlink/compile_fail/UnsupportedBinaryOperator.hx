// EXPECT_ERROR: Unsupported Quadrants HashLink binary operator
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedBinaryOperator {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = 0...4;
    });
  }
}
