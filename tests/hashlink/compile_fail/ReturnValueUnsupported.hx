// EXPECT_ERROR: Quadrants tuple return must contain at least one value
import quadrants.Context;
import quadrants.Kernel;

class ReturnValueUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      return [];
    });
  }
}
