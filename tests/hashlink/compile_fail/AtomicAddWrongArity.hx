// EXPECT_ERROR: Quadrants HashLink function atomicAdd expects 2 argument(s)
import quadrants.Context;
import quadrants.Kernel;

class AtomicAddWrongArity {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = atomicAdd(out[0]);
    });
  }
}
