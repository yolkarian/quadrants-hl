// EXPECT_ERROR: Unsupported Quadrants HashLink function call pow
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedFunctionCall {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = pow(2, 3);
    });
  }
}
