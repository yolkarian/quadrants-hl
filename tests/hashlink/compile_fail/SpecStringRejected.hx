// EXPECT_ERROR: Unsupported Quadrants typed kernel dtype String
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Spec;
import quadrants.Types.Arch;

class SpecStringRejected {
  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu});
    Kernel.build(ctx, macro (name:Spec<String>) -> {});
  }
}
