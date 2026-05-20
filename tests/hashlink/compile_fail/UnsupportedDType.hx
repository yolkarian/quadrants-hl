// EXPECT_ERROR: Unsupported Quadrants HashLink dtype String
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedDType {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (x:String, out) -> {
      out[0] = 1;
    });
  }
}
