// EXPECT_ERROR: Quadrants HashLink only supports ndarray element, vector component, matrix element, struct field, or local variable assignments
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class UnsupportedAssignmentTarget {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      out.length = 1;
    });
  }
}
