// EXPECT_ERROR: Quadrants matrix inverse in kernels requires F32 or F64 matrix values
import quadrants.Kernel;
import quadrants.Mat2;
import quadrants.Tensor;
import quadrants.Types.I32;

class MatrixI32InverseUnsupported {
  static function main():Void {
    Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      var m = Mat2.i32(1, 2, 3, 4);
      var inv = m.inverse();
      out[0] = inv[0];
    });
  }
}
