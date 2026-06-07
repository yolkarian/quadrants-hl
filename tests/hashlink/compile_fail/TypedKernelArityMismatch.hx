// EXPECT_ERROR: Not enough arguments
import quadrants.Context;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class TypedKernelArityMismatch {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var values = new Tensor<I32>(ctx, [4]);
    var out = new Tensor<I32>(ctx, [4]);
    var k = QD.kernel(ctx, macro (values:Tensor<I32>, out:Tensor<I32>) -> {
      out[0] = values[0];
    });
    k.launch(values);
  }
}
