package quadrants;

class Grouped {
  public static function of<D>(value:D, ?b:Int, ?c:Int, ?d:Int):GroupedDomain<D> {
    return cast value;
  }
}
