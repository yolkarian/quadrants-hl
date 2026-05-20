// EXPECT_ERROR: Quadrants HashLink continue must be inside a loop
import quadrants.Context;
import quadrants.Kernel;

class ContinueOutsideLoop {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      continue;
    });
  }
}
