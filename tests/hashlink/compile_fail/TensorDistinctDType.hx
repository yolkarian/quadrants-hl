// EXPECT_ERROR: Tensor_I8 should be quadrants._generated.Tensor_I32
import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I8;
import quadrants.Types.I32;

class TensorDistinctDType {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var a:Tensor<I8> = new Tensor<I8>(ctx, [1]);
    var b:Tensor<I32> = a;
  }
}
