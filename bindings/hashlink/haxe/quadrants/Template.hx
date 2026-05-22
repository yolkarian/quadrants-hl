package quadrants;

class Template {
  public static macro function specialize(dtype:haxe.macro.Expr, expression:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.TemplateMacro.specialize(dtype, expression);
  }

  public static macro function build(dtype:haxe.macro.Expr, ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    var specialized = quadrants.macro.TemplateMacro.specialize(dtype, fn);
    return options == null
      ? macro quadrants.Kernel.build($e{ctx}, $e{specialized})
      : macro quadrants.Kernel.build($e{ctx}, $e{specialized}, $e{options});
  }

  public static macro function descriptorBytes(dtype:haxe.macro.Expr, fn:haxe.macro.Expr):haxe.macro.Expr {
    return macro quadrants.Kernel.descriptorBytes($e{quadrants.macro.TemplateMacro.specialize(dtype, fn)});
  }
}
