// EXPECT_ERROR: Quadrants Static.values elements must be integer or float literals
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Static;
import quadrants.Tensor;
import quadrants.Types.I32;

class StaticValuesNonLiteral {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (bound:Int, out:Tensor<I32>) -> {
      for (v in Static.values([bound])) {
        out[0] += v;
      }
    });
  }
}
