// EXPECT_ERROR: Quadrants HashLink only supports ndarray element, vector component, matrix element, struct field, or local variable assignments
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedAssignmentTarget {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out.length = 1;
    });
  }
}
