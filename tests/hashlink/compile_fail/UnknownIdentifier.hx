// EXPECT_ERROR: Unknown Quadrants kernel identifier missing
import quadrants.Context;
import quadrants.Kernel;

class UnknownIdentifier {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = missing;
    });
  }
}
