// EXPECT_ERROR: Quadrants Ndrange.of3Axes expects AxisOrder.of3(...)
import quadrants.AxisOrder;
import quadrants.Grouped;
import quadrants.Kernel;
import quadrants.Ndrange;
import quadrants.Tensor;
import quadrants.Types.I32;

class GroupedNdrangeAxesMismatch {
  static function main():Void {
    Kernel.descriptorBytes(macro (out:Tensor<I32>, rows:I32, cols:I32, depth:I32) -> {
      for (I in Grouped.of(Ndrange.of3Axes(rows, cols, depth, AxisOrder.of2(0, 1)))) {
        out[0] = I[0];
      }
    });
  }
}
