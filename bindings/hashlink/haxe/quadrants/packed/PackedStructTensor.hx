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
