// EXPECT_ERROR: Quadrants HashLink supports one local variable declaration per statement
import quadrants.Context;
import quadrants.Kernel;

class MultipleLocalVarDecl {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var a = 1, b = 2;
      out[0] = a + b;
    });
  }
}
