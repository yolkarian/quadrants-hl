// EXPECT_ERROR: reverse/validate autodiff does not support while, break, or continue
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.AutodiffMode;

class AutodiffReverseWhile {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var _k = Kernel.build(ctx, macro (out:Tensor<F32>, n:Int) -> {
      var i = 0;
      while (i < n) {
        out[i] = 1.0;
        i = i + 1;
      }
    }, {autodiff: Reverse});
  }
}
