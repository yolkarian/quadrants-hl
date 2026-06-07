// EXPECT_ERROR: Quadrants HashLink volatileLoad target must be an ndarray element
import quadrants.Context;
import quadrants.Kernel;
import quadrants.SpecialOps;
import quadrants.Types.I32;

class VolatileLoadRequiresElement {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (x:I32) -> {
      return SpecialOps.volatileLoad(x);
    });
  }
}
