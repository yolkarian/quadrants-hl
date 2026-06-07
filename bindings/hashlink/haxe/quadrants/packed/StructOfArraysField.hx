package quadrants.packed;

import quadrants.Context;
import quadrants.FieldRuntime;

private typedef FieldMember = {
  var name:String;
  var field:Dynamic;
}

class StructOfArraysField {
  public var context(default, null):Context = null;
  public var shape(default, null):Array<Int> = null;
  final fields:Map<String, Dynamic> = [];
  final fieldNames:Array<String> = [];

  public function new(?members:Array<FieldMember>) {
    if (members != null) {
      for (member in members) {
        add(member.name, member.field);
      }
    }
  }

  public static function fromFields(members:Array<FieldMember>):StructOfArraysField {
    return new StructOfArraysField(members);
  }

  public function add(name:String, field:Dynamic):StructOfArraysField {
    validateName(name);
    if (fields.exists(name)) {
      throw 'Quadrants struct-of-arrays field ${name} already exists';
    }
    var runtime = requireField(field);
    if (runtime.shape == null) {
      throw 'Quadrants struct-of-arrays member ${name} has not been placed';
    }
    if (context == null) {
      context = runtime.context;
      shape = copyShape(runtime.shape);
    } else {
      if (runtime.context != context) {
        throw 'Quadrants struct-of-arrays member ${name} belongs to a different context';
      }
      requireSameShape(shape, runtime.shape, name);
    }
    fields.set(name, field);
    fieldNames.push(name);
    return this;
  }

  /** Typed member insertion for new code. The `add` method remains a compatibility shim. */
  public inline function addField<T>(name:String, field:quadrants.Field<T>):StructOfArraysField {
    return add(name, field);
  }

  public inline function addMember<T>(member:quadrants.StructMember<T>, field:quadrants.Field<T>):StructOfArraysField {
    return add(member.name, field);
  }

  public function members():Array<String> {
    return fieldNames.copy();
  }

  public function member(name:String):Dynamic {
    var field = fields.get(name);
    if (field == null) {
      throw 'Quadrants struct-of-arrays member ${name} is missing';
    }
    return field;
  }

  public inline function field(name:String):Dynamic {
    return member(name);
  }

  /** Typed member lookup for new code using the compatibility string-keyed container. */
  public inline function memberField<T>(name:String):quadrants.Field<T> {
    return cast member(name);
  }

  public inline function fieldAs<T>(name:String):quadrants.Field<T> {
    return memberField(name);
  }

  public inline function memberBy<T>(member:quadrants.StructMember<T>):quadrants.Field<T> {
    return memberField(member.name);
  }

  public function elementCount():Int {
    if (shape == null) {
      return 0;
    }
    var total = 1;
    for (dim in shape) total *= dim;
    return total;
  }

  public function read(name:String, flatIndex:Int):Dynamic {
    return member(name).read(flatIndex);
  }

  public function write(name:String, flatIndex:Int, value:Dynamic):Void {
    member(name).write(flatIndex, value);
  }

  public inline function readField<T>(name:String, flatIndex:Int):T {
    return memberField(name).read(flatIndex);
  }

  public inline function writeField<T>(name:String, flatIndex:Int, value:T):Void {
    memberField(name).write(flatIndex, value);
  }

  public inline function readMember<T>(member:quadrants.StructMember<T>, flatIndex:Int):T {
    return readField(member.name, flatIndex);
  }

  public inline function writeMember<T>(member:quadrants.StructMember<T>, flatIndex:Int, value:T):Void {
    writeField(member.name, flatIndex, value);
  }

  public inline function readValue1<T0>(member0:quadrants.StructMember<T0>, flatIndex:Int):quadrants.StructValue1<T0> {
    return quadrants.Struct.value1(member0, readMember(member0, flatIndex));
  }

  public inline function writeValue1<T0>(flatIndex:Int, value:quadrants.StructValue1<T0>):Void {
    writeMember(value.member0, flatIndex, value.value0);
  }

  public inline function readValue2<T0, T1>(member0:quadrants.StructMember<T0>, member1:quadrants.StructMember<T1>, flatIndex:Int):quadrants.StructValue2<T0, T1> {
    return quadrants.Struct.value2(member0, readMember(member0, flatIndex), member1, readMember(member1, flatIndex));
  }

  public inline function writeValue2<T0, T1>(flatIndex:Int, value:quadrants.StructValue2<T0, T1>):Void {
    writeMember(value.member0, flatIndex, value.value0);
    writeMember(value.member1, flatIndex, value.value1);
  }

  public inline function readValue3<T0, T1, T2>(member0:quadrants.StructMember<T0>, member1:quadrants.StructMember<T1>, member2:quadrants.StructMember<T2>, flatIndex:Int):quadrants.StructValue3<T0, T1, T2> {
    return quadrants.Struct.value3(member0, readMember(member0, flatIndex), member1, readMember(member1, flatIndex), member2, readMember(member2, flatIndex));
  }

  public inline function writeValue3<T0, T1, T2>(flatIndex:Int, value:quadrants.StructValue3<T0, T1, T2>):Void {
    writeMember(value.member0, flatIndex, value.value0);
    writeMember(value.member1, flatIndex, value.value1);
    writeMember(value.member2, flatIndex, value.value2);
  }

  public inline function readValue4<T0, T1, T2, T3>(member0:quadrants.StructMember<T0>, member1:quadrants.StructMember<T1>, member2:quadrants.StructMember<T2>, member3:quadrants.StructMember<T3>, flatIndex:Int):quadrants.StructValue4<T0, T1, T2, T3> {
    return quadrants.Struct.value4(member0, readMember(member0, flatIndex), member1, readMember(member1, flatIndex), member2, readMember(member2, flatIndex), member3, readMember(member3, flatIndex));
  }

  public inline function writeValue4<T0, T1, T2, T3>(flatIndex:Int, value:quadrants.StructValue4<T0, T1, T2, T3>):Void {
    writeMember(value.member0, flatIndex, value.value0);
    writeMember(value.member1, flatIndex, value.value1);
    writeMember(value.member2, flatIndex, value.value2);
    writeMember(value.member3, flatIndex, value.value3);
  }

  public function lazyGrad():StructOfArraysField {
    var grad = new StructOfArraysField();
    for (name in fieldNames) {
      grad.add(name, member(name).lazyGrad());
    }
    return grad;
  }

  public function lazyDual():StructOfArraysField {
    var dual = new StructOfArraysField();
    for (name in fieldNames) {
      dual.add(name, member(name).lazyDual());
    }
    return dual;
  }

  public function close():Void {
    for (name in fieldNames) {
      member(name).close();
    }
    fields.clear();
    fieldNames.resize(0);
    context = null;
    shape = null;
  }

  static function validateName(name:String):Void {
    if (name == null || name.length == 0) {
      throw "Quadrants struct member name must be non-empty";
    }
  }

  static function requireField(value:Dynamic):FieldRuntime {
    if (!Std.isOfType(value, FieldRuntime)) {
      throw "Quadrants struct-of-arrays storage must use Field members";
    }
    return cast value;
  }

  static function copyShape(input:Array<Int>):Array<Int> {
    return [for (dim in input) dim];
  }

  static function requireSameShape(expected:Array<Int>, actual:Array<Int>, name:String):Void {
    if (expected.length != actual.length) {
      throw 'Quadrants struct-of-arrays member ${name} shape mismatch';
    }
    for (i in 0...expected.length) {
      if (expected[i] != actual[i]) {
        throw 'Quadrants struct-of-arrays member ${name} shape mismatch';
      }
    }
  }
}
