// EXPECT_ERROR: Unsupported Quadrants typed kernel dtype QuantizedF32Tensor
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.quant.QuantizedF32Tensor;

class UnsupportedQuantKernelParameter {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    Kernel.build(ctx, macro (q:QuantizedF32Tensor) -> {
      var n = 0;
    });
  }
}
