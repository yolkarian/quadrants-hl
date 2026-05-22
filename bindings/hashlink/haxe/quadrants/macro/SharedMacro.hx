package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class SharedMacro {
  public static function array(dtype:Expr, size:Expr):Expr {
    return switch (strip(dtype).expr) {
      case EField(_, "I8") | EConst(CIdent("I8")): macro quadrants.Shared.arrayI8($e{size});
      case EField(_, "I16") | EConst(CIdent("I16")): macro quadrants.Shared.arrayI16($e{size});
      case EField(_, "I32") | EConst(CIdent("I32")): macro quadrants.Shared.arrayI32($e{size});
      case EField(_, "I64") | EConst(CIdent("I64")): macro quadrants.Shared.arrayI64($e{size});
      case EField(_, "U8") | EConst(CIdent("U8")): macro quadrants.Shared.arrayU8($e{size});
      case EField(_, "U16") | EConst(CIdent("U16")): macro quadrants.Shared.arrayU16($e{size});
      case EField(_, "U32") | EConst(CIdent("U32")): macro quadrants.Shared.arrayU32($e{size});
      case EField(_, "U64") | EConst(CIdent("U64")): macro quadrants.Shared.arrayU64($e{size});
      case EField(_, "U1") | EConst(CIdent("U1")): macro quadrants.Shared.arrayU1($e{size});
      case EField(_, "F16") | EConst(CIdent("F16")): macro quadrants.Shared.arrayF16($e{size});
      case EField(_, "F32") | EConst(CIdent("F32")): macro quadrants.Shared.arrayF32($e{size});
      case EField(_, "F64") | EConst(CIdent("F64")): macro quadrants.Shared.arrayF64($e{size});
      default: Context.error("Quadrants Shared.array expects a concrete DType enum value", dtype.pos);
    };
  }

  public static function tile16(dtype:Expr):Expr {
    return switch (strip(dtype).expr) {
      case EField(_, "I8") | EConst(CIdent("I8")): macro quadrants.Shared.tile16I8();
      case EField(_, "I16") | EConst(CIdent("I16")): macro quadrants.Shared.tile16I16();
      case EField(_, "I32") | EConst(CIdent("I32")): macro quadrants.Shared.tile16I32();
      case EField(_, "I64") | EConst(CIdent("I64")): macro quadrants.Shared.tile16I64();
      case EField(_, "U8") | EConst(CIdent("U8")): macro quadrants.Shared.tile16U8();
      case EField(_, "U16") | EConst(CIdent("U16")): macro quadrants.Shared.tile16U16();
      case EField(_, "U32") | EConst(CIdent("U32")): macro quadrants.Shared.tile16U32();
      case EField(_, "U64") | EConst(CIdent("U64")): macro quadrants.Shared.tile16U64();
      case EField(_, "U1") | EConst(CIdent("U1")): macro quadrants.Shared.tile16U1();
      case EField(_, "F16") | EConst(CIdent("F16")): macro quadrants.Shared.tile16F16();
      case EField(_, "F32") | EConst(CIdent("F32")): macro quadrants.Shared.tile16F32();
      case EField(_, "F64") | EConst(CIdent("F64")): macro quadrants.Shared.tile16F64();
      default: Context.error("Quadrants Shared.tile16 expects a concrete DType enum value", dtype.pos);
    };
  }

  static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _): strip(inner);
      default: expression;
    };
  }
}
#end
