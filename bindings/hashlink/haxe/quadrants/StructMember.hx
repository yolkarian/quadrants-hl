package quadrants;

/** Typed name handle for string-backed struct compatibility containers. */
class StructMember<T> {
  public final name:String;

  public function new(name:String) {
    if (name == null || name.length == 0) {
      throw "Quadrants struct member name must be non-empty";
    }
    this.name = name;
  }
}
