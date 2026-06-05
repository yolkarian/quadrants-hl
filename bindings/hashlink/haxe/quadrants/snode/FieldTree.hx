package quadrants.snode;

import quadrants.Field;
import quadrants.FieldRuntime;

class FieldTree {
  public static function lazyGrad(field:Dynamic):Dynamic {
    requireField(field, "lazyGrad");
    return field.lazyGrad();
  }

  public static function lazyDual(field:Dynamic):Dynamic {
    requireField(field, "lazyDual");
    return field.lazyDual();
  }

  public static function lazyFieldGrad<T>(field:Field<T>):Field<T> {
    return field.lazyGrad();
  }

  public static function lazyFieldDual<T>(field:Field<T>):Field<T> {
    return field.lazyDual();
  }

  public static function lazyFieldGrads<T>(fields:Array<Field<T>>):Array<Field<T>> {
    if (fields == null) {
      throw "Quadrants lazyFieldGrads field list is null";
    }
    return [for (field in fields) lazyFieldGrad(field)];
  }

  public static function lazyFieldDuals<T>(fields:Array<Field<T>>):Array<Field<T>> {
    if (fields == null) {
      throw "Quadrants lazyFieldDuals field list is null";
    }
    return [for (field in fields) lazyFieldDual(field)];
  }

  public static function lazyGrads(fields:Array<Dynamic>):Array<Dynamic> {
    if (fields == null) {
      throw "Quadrants lazyGrads field list is null";
    }
    return [for (field in fields) lazyGrad(field)];
  }

  public static function lazyDuals(fields:Array<Dynamic>):Array<Dynamic> {
    if (fields == null) {
      throw "Quadrants lazyDuals field list is null";
    }
    return [for (field in fields) lazyDual(field)];
  }

  static function requireField(value:Dynamic, operation:String):FieldRuntime {
    if (!Std.isOfType(value, FieldRuntime)) {
      throw 'Quadrants ${operation} expects a Field';
    }
    return cast value;
  }
}
