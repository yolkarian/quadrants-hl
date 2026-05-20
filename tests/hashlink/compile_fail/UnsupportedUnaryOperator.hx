// EXPECT_ERROR: Unsupported Quadrants HashLink unary operator
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedUnaryOperator {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var i = 0;
      out[0] = ++i;
    });
  }
}
