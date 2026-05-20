// EXPECT_ERROR: Unsupported quoted Haxe expression node ESwitch
import quadrants.Context;
import quadrants.Kernel;

class SwitchUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (x, out) -> {
      switch (x) {
        case 0:
          out[0] = 1;
        default:
          out[0] = 2;
      }
    });
  }
}
