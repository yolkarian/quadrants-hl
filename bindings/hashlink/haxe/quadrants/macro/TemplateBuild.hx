package quadrants.macro;

#if macro
import haxe.macro.Expr;

class TemplateBuild {
  public static function specKeyExpr(valueExpr:Expr):Expr {
    return macro quadrants.flatten.Flattened.specKey($e{valueExpr});
  }
}
#end
