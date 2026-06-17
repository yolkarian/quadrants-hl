// EXPECT_ERROR: Not enough type parameters for quadrants.Tensor
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;

class KernelParameterMissingDType {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    Kernel.build(ctx, macro (out:Tensor) -> {
      out[0] = 1;
    });
  }
}
