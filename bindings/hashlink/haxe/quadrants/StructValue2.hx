package quadrants;

class StructValue2<T0, T1> {
  public final member0:StructMember<T0>;
  public final member1:StructMember<T1>;
  public var value0:T0;
  public var value1:T1;

  public function new(member0:StructMember<T0>, value0:T0, member1:StructMember<T1>, value1:T1) {
    this.member0 = member0;
    this.value0 = value0;
    this.member1 = member1;
    this.value1 = value1;
  }

  public inline function field0():T0 {
    return value0;
  }

  public inline function field1():T1 {
    return value1;
  }
}
