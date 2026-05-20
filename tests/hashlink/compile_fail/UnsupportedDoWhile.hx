// EXPECT_ERROR: Quadrants HashLink does not support do-while loops
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedDoWhile {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var i = 0;
      do {
        out[i] = i;
        i = i + 1;
      } while (i < 4);
    });
  }
}
