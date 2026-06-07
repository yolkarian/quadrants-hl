// EXPECT_ERROR: Quadrants typed kernel parameter x requires an explicit type annotation
import quadrants.Context;
import quadrants.QD;
import quadrants.Types.Arch;

class TypedKernelMissingAnnotation {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    QD.kernel(ctx, macro (x) -> {
      return x;
    });
  }
}
