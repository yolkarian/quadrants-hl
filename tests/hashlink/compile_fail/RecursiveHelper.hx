// EXPECT_ERROR: Quadrants qdFunc first is recursive
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class RecursiveHelper {
  static function main():Void {
    Kernel.descriptorBytes(macro (out:Tensor<I32>, x:I32) -> {
      out[0] = RecursiveHelper.RecursiveHelperFns.first(x);
    }, {helpers: [RecursiveHelper.RecursiveHelperFns]});
  }
}

class RecursiveHelperFns {
  @:qdFunc
  public static function first(x:Int):Int {
    return RecursiveHelperFns.second(x);
  }

  @:qdFunc
  public static function second(x:Int):Int {
    return RecursiveHelperFns.first(x);
  }
}
