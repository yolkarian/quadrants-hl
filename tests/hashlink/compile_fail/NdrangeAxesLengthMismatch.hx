// EXPECT_ERROR: Quadrants Ndrange.of2Axes expects AxisOrder.of2(...)
import quadrants.AxisOrder;
import quadrants.Kernel;
import quadrants.Ndrange;
import quadrants.Tensor;
import quadrants.Types.I32;

class NdrangeAxesLengthMismatch {
  static function main():Void {
    Kernel.descriptorBytes(macro (out:Tensor<I32>, rows:I32, cols:I32) -> {
      for (I in Ndrange.of2Axes(rows, cols, AxisOrder.of3(0, 1, 2))) {
        out[I[0] * cols + I[1]] = 1;
      }
    });
  }
}
