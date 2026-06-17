package quadrants;

import quadrants.packed.StructOfArraysField;

private typedef StructFieldMember = {
  var name:String;
  var field:Dynamic;
}

class StructField {
  public var context(default, null):Context = null;
  public var shape(default, null):Array<Int> = null;
  final fields:Map<String, Dynamic> = [];
  final fieldNames:Array<String> = [];

  public function new(?members:Array<StructFieldMember>) {
    if (members != null) {
      for (member in members) {
        add(member.name, member.field);
      }
    }
  }

  public static function fromFields(members:Array<StructFieldMember>):StructField {
    return new StructField(members);
  }

  public static function alloc<S>(context:Context, shape:Array<Int>, layout:LayoutPolicy = LayoutPolicy.SOA):StructField {
    throw "Quadrants StructField<S> storage is scheduled for Phase 5; QdStruct metadata is required before allocation";
  }

  public static function fromStructOfArrays(source:StructOfArraysField):StructField {
    var result = new StructField();
    for (name in source.members()) {
      result.add(name, source.member(name));
    }
    return result;
  }

  public function toStructOfArrays():StructOfArraysField {
    var result = new StructOfArraysField();
    for (name in fieldNames) {
      result.add(name, member(name));
    }
    return result;
  }

  public function add(name:String, field:Dynamic):StructField {
    validateName(name);
    if (fields.exists(name)) {
      throw 'Quadrants StructField member ${name} already exists';
    }
    var runtime = requireField(field);
    if (runtime.shape == null) {
      throw 'Quadrants StructField member ${name} has not been placed';
    }
    if (context == null) {
      context = runtime.context;
      shape = copyShape(runtime.shape);
    } else {
      if (runtime.context != context) {
        throw 'Quadrants StructField member ${name} belongs to a different context';
      }
      requireSameShape(shape, runtime.shape, name);
    }
    fields.set(name, field);
    fieldNames.push(name);
    return this;
  }

  /** Typed member insertion for new code. The string-keyed `add` method remains a compatibility shim. */
  public inline function addField<T>(name:String, field:Field<T>):StructField {
    return add(name, field);
  }

  public inline function addMember<T>(member:StructMember<T>, field:Field<T>):StructField {
    return add(member.name, field);
  }

  public function members():Array<String> {
    return fieldNames.copy();
  }

  public function member(name:String):Dynamic {
    var field = fields.get(name);
    if (field == null) {
      throw 'Quadrants StructField member ${name} is missing';
    }
    return field;
  }

  public inline function field(name:String):Dynamic {
    return member(name);
  }

  /** Typed member lookup for new code using the compatibility string-keyed container. */
  public inline function memberField<T>(name:String):Field<T> {
    return cast member(name);
  }

  public inline function fieldAs<T>(name:String):Field<T> {
    return memberField(name);
  }

  public inline function memberBy<T>(member:StructMember<T>):Field<T> {
    return memberField(member.name);
  }

  public function elementCount():Int {
    if (shape == null) {
      return 0;
    }
    return TensorStorage.elementCount(shape);
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

  public inline function readMember<T>(member:StructMember<T>, flatIndex:Int):T {
    return readField(member.name, flatIndex);
  }

  public inline function writeMember<T>(member:StructMember<T>, flatIndex:Int, value:T):Void {
    writeField(member.name, flatIndex, value);
  }

  public inline function readValue1<T0>(member0:StructMember<T0>, flatIndex:Int):StructValue1<T0> {
    return Struct.value1(member0, readMember(member0, flatIndex));
  }

  public inline function writeValue1<T0>(flatIndex:Int, value:StructValue1<T0>):Void {
    writeMember(value.member0, flatIndex, value.value0);
  }

  public inline function readValue2<T0, T1>(member0:StructMember<T0>, member1:StructMember<T1>, flatIndex:Int):StructValue2<T0, T1> {
    return Struct.value2(member0, readMember(member0, flatIndex), member1, readMember(member1, flatIndex));
  }

  public inline function writeValue2<T0, T1>(flatIndex:Int, value:StructValue2<T0, T1>):Void {
    writeMember(value.member0, flatIndex, value.value0);
    writeMember(value.member1, flatIndex, value.value1);
  }

  public inline function readValue3<T0, T1, T2>(member0:StructMember<T0>, member1:StructMember<T1>, member2:StructMember<T2>, flatIndex:Int):StructValue3<T0, T1, T2> {
    return Struct.value3(member0, readMember(member0, flatIndex), member1, readMember(member1, flatIndex), member2, readMember(member2, flatIndex));
  }

  public inline function writeValue3<T0, T1, T2>(flatIndex:Int, value:StructValue3<T0, T1, T2>):Void {
    writeMember(value.member0, flatIndex, value.value0);
    writeMember(value.member1, flatIndex, value.value1);
    writeMember(value.member2, flatIndex, value.value2);
  }

  public inline function readValue4<T0, T1, T2, T3>(member0:StructMember<T0>, member1:StructMember<T1>, member2:StructMember<T2>, member3:StructMember<T3>, flatIndex:Int):StructValue4<T0, T1, T2, T3> {
    return Struct.value4(member0, readMember(member0, flatIndex), member1, readMember(member1, flatIndex), member2, readMember(member2, flatIndex), member3, readMember(member3, flatIndex));
  }

  public inline function writeValue4<T0, T1, T2, T3>(flatIndex:Int, value:StructValue4<T0, T1, T2, T3>):Void {
    writeMember(value.member0, flatIndex, value.value0);
    writeMember(value.member1, flatIndex, value.value1);
    writeMember(value.member2, flatIndex, value.value2);
    writeMember(value.member3, flatIndex, value.value3);
  }

  public function lazyGrad():StructField {
    var grad = new StructField();
    for (name in fieldNames) {
      grad.add(name, member(name).lazyGrad());
    }
    return grad;
  }

  public function lazyDual():StructField {
    var dual = new StructField();
    for (name in fieldNames) {
      dual.add(name, member(name).lazyDual());
    }
    return dual;
  }

  public function syncBeforeKernel():Void {
    for (name in fieldNames) {
      var field:FieldRuntime = cast member(name);
      field.syncSNodeToTensor();
      field.syncAutodiffPeersToTensor();
    }
  }

  public function syncAfterKernel():Void {
    for (name in fieldNames) {
      var field:FieldRuntime = cast member(name);
      field.syncTensorToSNode();
      field.syncAutodiffPeersFromTensor();
    }
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
      throw "Quadrants StructField member name must be non-empty";
    }
  }

  static function requireField(value:Dynamic):FieldRuntime {
    if (!Std.isOfType(value, FieldRuntime)) {
      throw "Quadrants StructField storage must use Field members";
    }
    return cast value;
  }

  static function copyShape(input:Array<Int>):Array<Int> {
    return [for (dim in input) dim];
  }

  static function requireSameShape(expected:Array<Int>, actual:Array<Int>, name:String):Void {
    if (expected.length != actual.length) {
      throw 'Quadrants StructField member ${name} shape mismatch';
    }
    for (i in 0...expected.length) {
      if (expected[i] != actual[i]) {
        throw 'Quadrants StructField member ${name} shape mismatch';
      }
    }
  }
}
