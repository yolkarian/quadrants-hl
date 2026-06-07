// EXPECT_ERROR: Unsupported Quadrants HashLink dtype StructValue2
import quadrants.Kernel;
import quadrants.StructValue2;
import quadrants.Tensor;
import quadrants.Types.I32;

class WholeStructParameterUnsupported {
  static function main():Void {
    Kernel.descriptorBytes(macro (value:StructValue2<I32, I32>, out:Tensor<I32>) -> {
      out[0] = value.value0;
    });
  }
}
