package quadrants.quant;

enum abstract QuantBits(Int) to Int {
  var Bits8 = 8;
  var Bits16 = 16;
  var Bits32 = 32;
  var Bits64 = 64;

  public static inline function isPhysicalContainerWidth(value:Int):Bool {
    return value == Bits8 || value == Bits16 || value == Bits32 || value == Bits64;
  }

  public static function requirePhysicalContainerWidth(value:Int):Int {
    if (!isPhysicalContainerWidth(value)) {
      throw "Quadrants quant physical container width must be 8, 16, 32, or 64 bits";
    }
    return value;
  }
}
