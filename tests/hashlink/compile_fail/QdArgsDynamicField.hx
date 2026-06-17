// EXPECT_ERROR: Quadrants QdArgs field bad cannot use Dynamic
import quadrants.macro.QdArgs;

@:build(quadrants.macro.QdArgs.build())
class BadQdArgsDynamic {
  public var bad:Dynamic;
  public function new() {}
}

class QdArgsDynamicField {
  static function main():Void {}
}
