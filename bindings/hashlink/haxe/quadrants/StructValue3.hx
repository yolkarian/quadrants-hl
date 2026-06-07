package quadrants;

class StructValue3<T0, T1, T2> {
  public final member0:StructMember<T0>;
  public final member1:StructMember<T1>;
  public final member2:StructMember<T2>;
  public var value0:T0;
  public var value1:T1;
  public var value2:T2;

  public function new(member0:StructMember<T0>, value0:T0, member1:StructMember<T1>, value1:T1, member2:StructMember<T2>, value2:T2) {
    this.member0 = member0;
    this.value0 = value0;
    this.member1 = member1;
    this.value1 = value1;
    this.member2 = member2;
    this.value2 = value2;
  }

  public inline function field0():T0 {
    return value0;
  }

  public inline function field1():T1 {
    return value1;
  }

  public inline function field2():T2 {
    return value2;
  }
}
