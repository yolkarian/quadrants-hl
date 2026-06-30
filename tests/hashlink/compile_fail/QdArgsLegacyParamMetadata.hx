// EXPECT_ERROR: Quadrants QdArgs field n must not use legacy @:param or @:template metadata
import quadrants.macro.QdArgs;

@:build(quadrants.macro.QdArgs.build())
class BadQdArgsLegacyParam {
  @:param public var n:Int;
  public function new() {}
}

class QdArgsLegacyParamMetadata {
  static function main():Void {}
}
