package quadrants.packed;

import quadrants.Context;
import quadrants.TensorRuntime;

private typedef TensorMember = {
  var name:String;
  var tensor:Dynamic;
}

class PackedStructTensor {
  public var context(default, null):Context = null;
  public var shape(default, null):Array<Int> = null;
  final tensors:Map<String, Dynamic> = [];
  final tensorNames:Array<String> = [];

  public function new(?members:Array<TensorMember>) {
    if (members != null) {
      for (member in members) {
        add(member.name, member.tensor);
      }
    }
  }

  public static function fromTensors(members:Array<TensorMember>):PackedStructTensor {
    return new PackedStructTensor(members);
  }

  public function add(name:String, tensor:Dynamic):PackedStructTensor {
    validateName(name);
    if (tensors.exists(name)) {
      throw 'Quadrants packed struct tensor member ${name} already exists';
    }
    var runtime = requireTensor(tensor);
    if (context == null) {
      context = runtime.context;
      shape = copyShape(runtime.shape);
    } else {
      if (runtime.context != context) {
        throw 'Quadrants packed struct tensor member ${name} belongs to a different context';
      }
      requireSameShape(shape, runtime.shape, name);
    }
    tensors.set(name, tensor);
    tensorNames.push(name);
    return this;
  }

  /** Typed member insertion for new code. The `add` method remains a compatibility shim. */
  public inline function addTensor<T>(name:String, tensor:quadrants.Tensor<T>):PackedStructTensor {
    return add(name, tensor);
  }

  public inline function addMember<T>(member:quadrants.StructMember<T>, tensor:quadrants.Tensor<T>):PackedStructTensor {
    return add(member.name, tensor);
  }

  public function members():Array<String> {
    return tensorNames.copy();
  }

  public function member(name:String):Dynamic {
    var tensor = tensors.get(name);
    if (tensor == null) {
      throw 'Quadrants packed struct tensor member ${name} is missing';
    }
    return tensor;
  }

  public inline function tensor(name:String):Dynamic {
    return member(name);
  }

  /** Typed tensor lookup for new code using the compatibility string-keyed container. */
  public inline function memberTensor<T>(name:String):quadrants.Tensor<T> {
    return cast member(name);
  }

  public inline function tensorAs<T>(name:String):quadrants.Tensor<T> {
    return memberTensor(name);
  }

  public inline function memberBy<T>(member:quadrants.StructMember<T>):quadrants.Tensor<T> {
    return memberTensor(member.name);
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

  public inline function readTensor<T>(name:String, flatIndex:Int):T {
    return memberTensor(name).read(flatIndex);
  }

  public inline function writeTensor<T>(name:String, flatIndex:Int, value:T):Void {
    memberTensor(name).write(flatIndex, value);
  }

  public inline function readMember<T>(member:quadrants.StructMember<T>, flatIndex:Int):T {
    return readTensor(member.name, flatIndex);
  }

  public inline function writeMember<T>(member:quadrants.StructMember<T>, flatIndex:Int, value:T):Void {
    writeTensor(member.name, flatIndex, value);
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

  public function close():Void {
    for (name in tensorNames) {
      member(name).close();
    }
    tensors.clear();
    tensorNames.resize(0);
    context = null;
    shape = null;
  }

  static function validateName(name:String):Void {
    if (name == null || name.length == 0) {
      throw "Quadrants packed struct tensor member name must be non-empty";
    }
  }

  static function requireTensor(value:Dynamic):TensorRuntime {
    if (!Std.isOfType(value, TensorRuntime)) {
      throw "Quadrants packed struct storage must use Tensor members";
    }
    return cast value;
  }

  static function copyShape(input:Array<Int>):Array<Int> {
    return [for (dim in input) dim];
  }

  static function requireSameShape(expected:Array<Int>, actual:Array<Int>, name:String):Void {
    if (expected.length != actual.length) {
      throw 'Quadrants packed struct tensor member ${name} shape mismatch';
    }
    for (i in 0...expected.length) {
      if (expected[i] != actual[i]) {
        throw 'Quadrants packed struct tensor member ${name} shape mismatch';
      }
    }
  }
}
