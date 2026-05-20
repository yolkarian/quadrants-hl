// EXPECT_ERROR: quadrants.Kernel.build expects a macro arrow function
import quadrants.Context;
import quadrants.Kernel;

class NonArrowKernel {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro 1 + 2);
  }
}
