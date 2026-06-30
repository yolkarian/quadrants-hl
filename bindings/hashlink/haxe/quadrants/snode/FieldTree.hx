package quadrants.snode;

import quadrants.Field;

class FieldTree {
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
}
