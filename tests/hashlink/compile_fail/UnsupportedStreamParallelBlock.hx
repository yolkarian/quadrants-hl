// EXPECT_ERROR: StreamParallel.block requires native multi-stream lowering
import quadrants.Context;
import quadrants.Kernel;
import quadrants.StreamParallel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class UnsupportedStreamParallelBlock {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      StreamParallel.block(() -> {
        out[0] = 1;
      });
    });
  }
}
