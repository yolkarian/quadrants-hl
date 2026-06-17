// EXPECT_ERROR: Quadrants QdStruct field label cannot use String

@:build(quadrants.macro.QdStruct.build())
class BadStructStringMember {
  public var label:String;
}

class StructMemberTypeAssumption {
  static function main():Void {}
}
