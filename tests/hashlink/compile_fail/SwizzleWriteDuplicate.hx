// EXPECT_ERROR: Quadrants swizzle assignment requires distinct components
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Vec2;
import quadrants.Vec3;

class SwizzleWriteDuplicate {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var v = Vec3.i32(1, 2, 3);
      v.xx = Vec2.i32(4, 5);
      out[0] = v[0];
    });
  }
}
