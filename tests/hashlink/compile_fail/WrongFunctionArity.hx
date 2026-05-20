// EXPECT_ERROR: Quadrants HashLink function sqrt expects 1 argument(s)
import quadrants.Context;
import quadrants.Kernel;

class WrongFunctionArity {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out) -> {
      out[0] = sqrt(4, 5);
    });
  }
}
