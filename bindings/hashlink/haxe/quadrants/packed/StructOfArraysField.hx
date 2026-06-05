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
