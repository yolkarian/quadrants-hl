// EXPECT_ERROR: Quadrants QuantizedF32Tensor.write(index, value) expects two arguments in kernels
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.quant.QuantizedF32Tensor;

class UnsupportedQuantKernelParameter {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    Kernel.build(ctx, macro (q:QuantizedF32Tensor) -> {
      q.write(0);
    });
  }
}
