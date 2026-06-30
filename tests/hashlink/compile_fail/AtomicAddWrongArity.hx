// EXPECT_ERROR: Quadrants HashLink function atomicAdd expects 2 argument(s)
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class AtomicAddWrongArity {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out[0] = atomicAdd(out[0]);
    });
  }
}
