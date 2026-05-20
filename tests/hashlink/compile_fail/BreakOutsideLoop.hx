// EXPECT_ERROR: Quadrants HashLink break must be inside a loop
import quadrants.Context;
import quadrants.Kernel;

class BreakOutsideLoop {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      break;
    });
  }
}
