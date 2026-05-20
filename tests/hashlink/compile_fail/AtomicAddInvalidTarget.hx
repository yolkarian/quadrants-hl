// EXPECT_ERROR: Quadrants HashLink atomicAdd target must be an ndarray element
import quadrants.Context;
import quadrants.Kernel;

class AtomicAddInvalidTarget {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      var x = 0;
      out[0] = atomicAdd(x, 1);
    });
  }
}
