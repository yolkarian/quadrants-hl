package quadrants;

class Shared {
  public static macro function array(dtype:haxe.macro.Expr, size:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.SharedMacro.array(dtype, size);
  }

  public static macro function tile16(dtype:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.SharedMacro.tile16(dtype);
  }

  #if !macro
  public static function arrayI8(size:Int):Tensor<quadrants.Types.I8> {
    throw "Quadrants Shared.arrayI8 is a kernel-only construct";
  }

  public static function arrayI16(size:Int):Tensor<quadrants.Types.I16> {
    throw "Quadrants Shared.arrayI16 is a kernel-only construct";
  }

  public static function arrayI32(size:Int):Tensor<quadrants.Types.I32> {
    throw "Quadrants Shared.arrayI32 is a kernel-only construct";
  }

  public static function arrayI64(size:Int):Tensor<quadrants.Types.I64> {
    throw "Quadrants Shared.arrayI64 is a kernel-only construct";
  }

  public static function arrayU8(size:Int):Tensor<quadrants.Types.U8> {
    throw "Quadrants Shared.arrayU8 is a kernel-only construct";
  }

  public static function arrayU16(size:Int):Tensor<quadrants.Types.U16> {
    throw "Quadrants Shared.arrayU16 is a kernel-only construct";
  }

  public static function arrayU32(size:Int):Tensor<quadrants.Types.U32> {
    throw "Quadrants Shared.arrayU32 is a kernel-only construct";
  }

  public static function arrayU64(size:Int):Tensor<quadrants.Types.U64> {
    throw "Quadrants Shared.arrayU64 is a kernel-only construct";
  }

  public static function arrayU1(size:Int):Tensor<quadrants.Types.U1> {
    throw "Quadrants Shared.arrayU1 is a kernel-only construct";
  }

  public static function arrayF32(size:Int):Tensor<quadrants.Types.F32> {
    throw "Quadrants Shared.arrayF32 is a kernel-only construct";
  }

  public static function arrayF16(size:Int):Tensor<quadrants.Types.F16> {
    throw "Quadrants Shared.arrayF16 is a kernel-only construct";
  }

  public static function arrayF64(size:Int):Tensor<quadrants.Types.F64> {
    throw "Quadrants Shared.arrayF64 is a kernel-only construct";
  }

  public static function tile16I8():Tensor<quadrants.Types.I8> {
    throw "Quadrants Shared.tile16I8 is a kernel-only construct";
  }

  public static function tile16I16():Tensor<quadrants.Types.I16> {
    throw "Quadrants Shared.tile16I16 is a kernel-only construct";
  }

  public static function tile16I32():Tensor<quadrants.Types.I32> {
    throw "Quadrants Shared.tile16I32 is a kernel-only construct";
  }

  public static function tile16I64():Tensor<quadrants.Types.I64> {
    throw "Quadrants Shared.tile16I64 is a kernel-only construct";
  }

  public static function tile16U8():Tensor<quadrants.Types.U8> {
    throw "Quadrants Shared.tile16U8 is a kernel-only construct";
  }

  public static function tile16U16():Tensor<quadrants.Types.U16> {
    throw "Quadrants Shared.tile16U16 is a kernel-only construct";
  }

  public static function tile16U32():Tensor<quadrants.Types.U32> {
    throw "Quadrants Shared.tile16U32 is a kernel-only construct";
  }

  public static function tile16U64():Tensor<quadrants.Types.U64> {
    throw "Quadrants Shared.tile16U64 is a kernel-only construct";
  }

  public static function tile16U1():Tensor<quadrants.Types.U1> {
    throw "Quadrants Shared.tile16U1 is a kernel-only construct";
  }

  public static function tile16F32():Tensor<quadrants.Types.F32> {
    throw "Quadrants Shared.tile16F32 is a kernel-only construct";
  }

  public static function tile16F16():Tensor<quadrants.Types.F16> {
    throw "Quadrants Shared.tile16F16 is a kernel-only construct";
  }

  public static function tile16F64():Tensor<quadrants.Types.F64> {
    throw "Quadrants Shared.tile16F64 is a kernel-only construct";
  }
  #end
}
