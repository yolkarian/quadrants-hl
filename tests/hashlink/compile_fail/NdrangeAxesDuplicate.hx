// EXPECT_ERROR: Quadrants AxisOrder.of2 arguments must be a permutation of 0...2
import quadrants.AxisOrder;
import quadrants.Kernel;
import quadrants.Ndrange;
import quadrants.Tensor;
import quadrants.Types.I32;

class NdrangeAxesDuplicate {
  static function main():Void {
    Kernel.descriptorBytes(macro (out:Tensor<I32>, rows:I32, cols:I32) -> {
      for (I in Ndrange.of2Axes(rows, cols, AxisOrder.of2(0, 0))) {
        out[I[0] * cols + I[1]] = 1;
      }
    });
  }
}
