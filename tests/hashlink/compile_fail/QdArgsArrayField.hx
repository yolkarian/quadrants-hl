// EXPECT_ERROR: Quadrants QdArgs field values cannot use Array<T>

@:build(quadrants.macro.QdArgs.build())
class BadQdArgsArray {
  public var values:Array<Int>;
  public function new() {}
}

class QdArgsArrayField {
  static function main():Void {}
}
