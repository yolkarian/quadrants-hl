// EXPECT_ERROR: quadrants.F32 should be quadrants.I32
import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.I32;

class TensorWriteWrongType {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var a = new Tensor<I32>(ctx, [1]);
    var f:F32 = 1.0;
    a.write(0, f);
  }
}
