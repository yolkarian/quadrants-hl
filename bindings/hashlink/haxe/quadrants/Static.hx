package quadrants;

class Static {
  public static inline function range(begin:Int, end:Int):Iterator<Int> {
    return begin...end;
  }

  public static inline function value<T>(value:T):T {
    return value;
  }

  public static inline function values<T>(list:Array<T>):Array<T> {
    return list;
  }
}
