// EXPECT_ERROR: Duplicate Quadrants local variable x
import quadrants.Context;
import quadrants.Kernel;

class DuplicateLocal {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var x = 1;
      var x = 2;
      out[0] = x;
    });
  }
}
