// EXPECT_ERROR: Duplicate Quadrants qdFunc helper name value
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class DuplicateHelperName {
  static function main():Void {
    Kernel.descriptorBytes(macro (out:Tensor<I32>, x:I32) -> {
      out[0] = DuplicateHelperName.DuplicateHelperA.value(x);
    }, {helpers: [DuplicateHelperName.DuplicateHelperA, DuplicateHelperName.DuplicateHelperB]});
  }
}

class DuplicateHelperA {
  @:qdFunc
  public static function value(x:Int):Int {
    return x;
  }
}

class DuplicateHelperB {
  @:qdFunc
  public static function value(x:Int):Int {
    return x + 1;
  }
}
