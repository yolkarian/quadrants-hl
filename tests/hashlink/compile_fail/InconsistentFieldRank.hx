// EXPECT_ERROR: Quadrants field parameter field is used with inconsistent rank
import quadrants.Context;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.Types.I32;

class InconsistentFieldRank {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (field:Field<I32>) -> {
      field[0] = field[0][0];
    });
  }
}
