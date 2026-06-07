// EXPECT_ERROR: should be quadrants._generated.Tensor_I32
import quadrants.Context;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.I32;

class TypedKernelDTypeMismatch {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var values = new Tensor<F32>(ctx, [4]);
    var out = new Tensor<I32>(ctx, [4]);
    var k = QD.kernel(ctx, macro (values:Tensor<I32>, out:Tensor<I32>) -> {
      out[0] = values[0];
    });
    k.launch(values, out);
  }
}
