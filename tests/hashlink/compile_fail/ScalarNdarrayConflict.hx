// EXPECT_ERROR: Quadrants parameter a is used as both ndarray and scalar
import quadrants.Context;
import quadrants.Kernel;

class ScalarNdarrayConflict {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (a, out) -> {
      out[0] = a[0] + a;
    });
  }
}
