// EXPECT_ERROR: Quadrants local variable out shadows a kernel parameter
import quadrants.Context;
import quadrants.Kernel;

class LocalShadowsParameter {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var out = 1;
    });
  }
}
