package quadrants;

class Kernel {
  public static macro function build(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.FlattenBuild.build(ctx, fn, options, false, "quadrants.Kernel.build");
  }

  @:noCompletion public static macro function buildRaw(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.buildRaw(ctx, fn, options);
  }

  public static macro function descriptorBytes(fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.descriptorBytes(fn, options);
  }
}
