// EXPECT_ERROR: Quadrants HashLink range-for only supports 0...n style ranges
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedForIterable {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (n, out) -> {
      for (i in n) {
        out[i] = i;
      }
    });
  }
}
