// EXPECT_ERROR: Unsupported Quadrants HashLink function call hypot
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedFunctionCall {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = hypot(3, 4);
    });
  }
}
