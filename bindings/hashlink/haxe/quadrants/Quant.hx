package quadrants;

import quadrants.quant.QuantBits;
import quadrants.quant.QuantFixed;
import quadrants.quant.QuantFloat;
import quadrants.quant.QuantInt;
import quadrants.quant.QuantSignedness;
import quadrants.Types.F32;
import quadrants.Types.I32;

typedef QuantIntOptions = {
  var bits:Int;
  var signed:Bool;
}

typedef QuantFixedOptions = {
  var bits:Int;
  var signed:Bool;
  @:optional var fractionalBits:Int;
  @:optional var scale:Float;
}

typedef QuantFloatOptions = {
  var exp:Int;
  var frac:Int;
  var signed:Bool;
}

class Quant {
  public static function intI32(options:QuantIntOptions):QuantInt<I32, I32> {
    requireBits(options == null ? 0 : options.bits);
    return quadrants.quant.Quant.intI32(bits(options.bits), signed(options.signed));
  }

  public static function fixedF32(options:QuantFixedOptions):QuantFixed<I32, F32> {
    requireBits(options == null ? 0 : options.bits);
    var fractionalBits = options.fractionalBits == null
      ? (options.scale == null ? 0 : scaleToFractionalBits(options.scale))
      : options.fractionalBits;
    return quadrants.quant.Quant.fixedF32(bits(options.bits), signed(options.signed), fractionalBits);
  }

  public static function floatF32(options:QuantFloatOptions):QuantFloat<I32, F32> {
    if (options == null || options.exp <= 0 || options.frac < 0) {
      throw "Quadrants Quant.floatF32 requires positive exp and non-negative frac";
    }
    return quadrants.quant.Quant.floatF32(options.exp, options.frac, signed(options.signed));
  }

  static function bits(value:Int):QuantBits {
    return switch (value) {
      case 8: QuantBits.Bits8;
      case 16: QuantBits.Bits16;
      case 32: QuantBits.Bits32;
      default: throw "Quadrants HashLink quant placement currently supports 8, 16, or 32 bits";
    };
  }

  static function signed(value:Bool):QuantSignedness {
    return value ? QuantSignedness.Signed : QuantSignedness.Unsigned;
  }

  static function requireBits(value:Int):Void {
    if (value <= 0 || value > 64) {
      throw "Quadrants quant bits must be in 1...64";
    }
  }

  static function scaleToFractionalBits(scale:Float):Int {
    if (!(scale > 0.0)) {
      throw "Quadrants Quant.fixedF32 scale must be positive";
    }
    return Std.int(Math.round(-Math.log(scale) / Math.log(2.0)));
  }
}
