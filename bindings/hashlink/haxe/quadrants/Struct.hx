package quadrants;

class Struct {
  public static macro function decode(typeExpr:haxe.macro.Expr, valuesExpr:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.StructMacro.decode(typeExpr, valuesExpr);
  }

  public static macro function decodeSchema(schemaExpr:haxe.macro.Expr, valuesExpr:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.StructMacro.decodeSchema(schemaExpr, valuesExpr);
  }

  public static inline function value1<T0>(member0:StructMember<T0>, value0:T0):StructValue1<T0> {
    return new StructValue1(member0, value0);
  }

  public static inline function value2<T0, T1>(member0:StructMember<T0>, value0:T0, member1:StructMember<T1>, value1:T1):StructValue2<T0, T1> {
    return new StructValue2(member0, value0, member1, value1);
  }

  public static inline function value3<T0, T1, T2>(member0:StructMember<T0>, value0:T0, member1:StructMember<T1>, value1:T1, member2:StructMember<T2>, value2:T2):StructValue3<T0, T1, T2> {
    return new StructValue3(member0, value0, member1, value1, member2, value2);
  }

  public static inline function value4<T0, T1, T2, T3>(member0:StructMember<T0>, value0:T0, member1:StructMember<T1>, value1:T1, member2:StructMember<T2>, value2:T2, member3:StructMember<T3>, value3:T3):StructValue4<T0, T1, T2, T3> {
    return new StructValue4(member0, value0, member1, value1, member2, value2, member3, value3);
  }

  public static function of1(name0:String, value0:Dynamic):Dynamic {
    throw "Quadrants Struct.of1 is a kernel-only construct";
  }

  public static function of2(name0:String, value0:Dynamic, name1:String, value1:Dynamic):Dynamic {
    throw "Quadrants Struct.of2 is a kernel-only construct";
  }

  public static function of3(name0:String, value0:Dynamic, name1:String, value1:Dynamic, name2:String, value2:Dynamic):Dynamic {
    throw "Quadrants Struct.of3 is a kernel-only construct";
  }

  public static function of4(name0:String, value0:Dynamic, name1:String, value1:Dynamic, name2:String, value2:Dynamic, name3:String, value3:Dynamic):Dynamic {
    throw "Quadrants Struct.of4 is a kernel-only construct";
  }

  public static function of5(name0:String, value0:Dynamic, name1:String, value1:Dynamic, name2:String, value2:Dynamic, name3:String, value3:Dynamic, name4:String, value4:Dynamic):Dynamic {
    throw "Quadrants Struct.of5 is a kernel-only construct";
  }

  public static function of6(name0:String, value0:Dynamic, name1:String, value1:Dynamic, name2:String, value2:Dynamic, name3:String, value3:Dynamic, name4:String, value4:Dynamic, name5:String, value5:Dynamic):Dynamic {
    throw "Quadrants Struct.of6 is a kernel-only construct";
  }

  public static function of7(name0:String, value0:Dynamic, name1:String, value1:Dynamic, name2:String, value2:Dynamic, name3:String, value3:Dynamic, name4:String, value4:Dynamic, name5:String, value5:Dynamic, name6:String, value6:Dynamic):Dynamic {
    throw "Quadrants Struct.of7 is a kernel-only construct";
  }

  public static function of8(name0:String, value0:Dynamic, name1:String, value1:Dynamic, name2:String, value2:Dynamic, name3:String, value3:Dynamic, name4:String, value4:Dynamic, name5:String, value5:Dynamic, name6:String, value6:Dynamic, name7:String, value7:Dynamic):Dynamic {
    throw "Quadrants Struct.of8 is a kernel-only construct";
  }
}
