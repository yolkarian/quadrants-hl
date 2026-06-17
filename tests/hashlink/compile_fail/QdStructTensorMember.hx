// EXPECT_ERROR: Quadrants QdStruct field tensor cannot use Tensor/Field resources
import quadrants.Tensor;
import quadrants.Types.I32;

@:build(quadrants.macro.QdStruct.build())
class BadStructTensorMember {
  public var tensor:Tensor<I32>;
}

class QdStructTensorMember {
  static function main():Void {}
}
