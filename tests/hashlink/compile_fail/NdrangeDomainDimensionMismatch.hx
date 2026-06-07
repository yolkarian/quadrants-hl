// EXPECT_ERROR: quadrants.Ndrange2 should be quadrants.Ndrange3
import quadrants.Ndrange;
import quadrants.Ndrange3;

class NdrangeDomainDimensionMismatch {
  static function main():Void {
    var domain:Ndrange3 = Ndrange.of2(1, 2);
    if (domain != null) throw "unexpected marker";
  }
}
