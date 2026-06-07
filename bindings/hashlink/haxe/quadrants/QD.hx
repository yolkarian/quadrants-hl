package quadrants;

class QD {
  public static macro function kernel(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.FlattenBuild.build(ctx, fn, options);
  }
}
