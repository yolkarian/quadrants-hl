// EXPECT_ERROR: Unsupported quoted Haxe expression node EArrayDecl
import quadrants.Context;
import quadrants.Kernel;

class ArrayLiteralUnsupported {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = [1, 2];
    });
  }
}
