package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Printer;

class TemplateMacro {
  public static function specialize(dtype:Expr, expression:Expr):Expr {
    var concreteType = concreteTypePath(dtype);
    var printed = new Printer().printExpr(unwrapMacroQuote(expression));
    printed = StringTools.replace(printed, "quadrants.TemplateDType", concreteType);
    printed = StringTools.replace(printed, "TemplateDType", concreteType);
    return Context.parse(printed, expression.pos);
  }

  static function concreteTypePath(dtype:Expr):String {
    return switch (strip(dtype).expr) {
      case EField(_, field) if (isSupportedDType(field)): 'quadrants.Types.${field}';
      case EConst(CIdent(field)) if (isSupportedDType(field)): 'quadrants.Types.${field}';
      default:
        Context.error("quadrants.Template expects a DType enum value such as DType.I32", dtype.pos);
    };
  }

  static function isSupportedDType(name:String):Bool {
    return switch (name) {
      case "I8" | "I16" | "I32" | "I64" | "U8" | "U16" | "U32" | "U64" | "U1" | "F16" | "F32" | "F64": true;
      default: false;
    };
  }

  static function unwrapMacroQuote(expression:Expr):Expr {
    var expr = strip(expression);
    return switch (expr.expr) {
      case ECall({expr: EConst(CIdent("macro"))}, [quoted]): strip(quoted);
      default: expr;
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
