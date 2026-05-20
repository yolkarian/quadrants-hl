// EXPECT_ERROR: Duplicate Quadrants kernel parameter out
import quadrants.Context;
import quadrants.Kernel;

class DuplicateParameter {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out, out) -> {
      out[0] = 1;
    });
  }
}
