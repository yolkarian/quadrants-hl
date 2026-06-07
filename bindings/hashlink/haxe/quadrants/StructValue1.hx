package quadrants;

class StructValue1<T0> {
  public final member0:StructMember<T0>;
  public var value0:T0;

  public function new(member0:StructMember<T0>, value0:T0) {
    this.member0 = member0;
    this.value0 = value0;
  }

  public inline function field0():T0 {
    return value0;
  }
}
