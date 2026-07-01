package quadrants;

abstract StructValue(Dynamic) {}

class Struct {
  public static macro function decode(typeExpr:haxe.macro.Expr, valuesExpr:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.StructMacro.decode(typeExpr, valuesExpr);
  }

  public static macro function decodeSchema(schemaExpr:haxe.macro.Expr, valuesExpr:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.StructMacro.decodeSchema(schemaExpr, valuesExpr);
  }

  @:noCompletion public static function of1<T0>(name0:String, value0:T0):StructValue {
    throw "Quadrants Struct.of1 is a kernel-only construct";
  }

  @:noCompletion public static function of2<T0, T1>(name0:String, value0:T0, name1:String, value1:T1):StructValue {
    throw "Quadrants Struct.of2 is a kernel-only construct";
  }

  @:noCompletion public static function of3<T0, T1, T2>(name0:String, value0:T0, name1:String, value1:T1, name2:String, value2:T2):StructValue {
    throw "Quadrants Struct.of3 is a kernel-only construct";
  }

  @:noCompletion public static function of4<T0, T1, T2, T3>(name0:String, value0:T0, name1:String, value1:T1, name2:String, value2:T2, name3:String, value3:T3):StructValue {
    throw "Quadrants Struct.of4 is a kernel-only construct";
  }

  @:noCompletion public static function of5<T0, T1, T2, T3, T4>(name0:String, value0:T0, name1:String, value1:T1, name2:String, value2:T2, name3:String, value3:T3, name4:String, value4:T4):StructValue {
    throw "Quadrants Struct.of5 is a kernel-only construct";
  }

  @:noCompletion public static function of6<T0, T1, T2, T3, T4, T5>(name0:String, value0:T0, name1:String, value1:T1, name2:String, value2:T2, name3:String, value3:T3, name4:String, value4:T4, name5:String, value5:T5):StructValue {
    throw "Quadrants Struct.of6 is a kernel-only construct";
  }

  @:noCompletion public static function of7<T0, T1, T2, T3, T4, T5, T6>(name0:String, value0:T0, name1:String, value1:T1, name2:String, value2:T2, name3:String, value3:T3, name4:String, value4:T4, name5:String, value5:T5, name6:String, value6:T6):StructValue {
    throw "Quadrants Struct.of7 is a kernel-only construct";
  }

  @:noCompletion public static function of8<T0, T1, T2, T3, T4, T5, T6, T7>(name0:String, value0:T0, name1:String, value1:T1, name2:String, value2:T2, name3:String, value3:T3, name4:String, value4:T4, name5:String, value5:T5, name6:String, value6:T6, name7:String, value7:T7):StructValue {
    throw "Quadrants Struct.of8 is a kernel-only construct";
  }
}
