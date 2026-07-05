package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

class NativeLibrary {
  public static macro function build():Array<Field> {
    return Context.getBuildFields();
  }

  public static macro function runtimeLibDir():ExprOf<String> {
    return macro "";
  }
}
