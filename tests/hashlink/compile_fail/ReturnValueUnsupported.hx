// EXPECT_ERROR: Unsupported Quadrants HashLink kernel statement
import quadrants.Context;
import quadrants.Kernel;

class ReturnValueUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      return 1;
    });
  }
}
