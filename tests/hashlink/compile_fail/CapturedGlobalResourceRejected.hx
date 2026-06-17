// EXPECT_ERROR: Quadrants ndarray globalField is not a kernel parameter
import quadrants.Context;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class CapturedGlobalResourceRejected {
  static var globalField:Field<I32>;
  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu});
    globalField = new Field<I32>(ctx, [1]);
    Kernel.build(ctx, macro () -> {
      globalField[0] = 1;
    });
  }
}
