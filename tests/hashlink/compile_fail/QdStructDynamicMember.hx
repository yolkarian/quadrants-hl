// EXPECT_ERROR: Quadrants QdStruct field value cannot use Dynamic

@:build(quadrants.macro.QdStruct.build())
class BadStructDynamicMember {
  public var value:Dynamic;
}

class QdStructDynamicMember {
  static function main():Void {}
}
