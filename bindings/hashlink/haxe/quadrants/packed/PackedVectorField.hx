package quadrants.packed;

import quadrants.Context;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;
import quadrants.Vector;

class PackedVectorField<T> {
  public final storage:Field<T>;
  public final context:Context;
  public final components:Int;
  public final length:Int;

  public function new(storage:Field<T>, components:Int) {
    if (components <= 0 || components > 4) {
      throw "Quadrants packed vector component count must be in 1...4";
    }
    var runtime:FieldRuntime = cast storage;
    if (runtime.shape == null || runtime.shape.length == 0) {
      throw "Quadrants packed vector field requires storage elements";
    }
    if (runtime.elementCount() % components != 0) {
      throw "Quadrants packed vector field element count must be divisible by component count";
    }
    if (runtime.shape.length > 1 && runtime.shape[runtime.shape.length - 1] != components) {
      throw "Quadrants packed vector field trailing dimension must match component count";
    }
    this.storage = storage;
    this.context = runtime.context;
    this.components = components;
    this.length = Std.int(runtime.elementCount() / components);
  }

  public static function i32(context:Context, length:Int, components:Int):PackedVectorField<I32> {
    return new PackedVectorField<I32>(new Field<I32>(context, [length * components]), components);
  }

  public static function u32(context:Context, length:Int, components:Int):PackedVectorField<U32> {
    return new PackedVectorField<U32>(new Field<U32>(context, [length * components]), components);
  }

  public static function f32(context:Context, length:Int, components:Int):PackedVectorField<F32> {
    return new PackedVectorField<F32>(new Field<F32>(context, [length * components]), components);
  }

  public static function f64(context:Context, length:Int, components:Int):PackedVectorField<F64> {
    return new PackedVectorField<F64>(new Field<F64>(context, [length * components]), components);
  }

  public static function fromField<T>(storage:Field<T>, components:Int):PackedVectorField<T> {
    return new PackedVectorField<T>(storage, components);
  }

  inline function flatIndex(index:Int, component:Int):Int {
    if (index < 0 || index >= length) {
      throw "Quadrants packed vector index out of bounds";
    }
    if (component < 0 || component >= components) {
      throw "Quadrants packed vector component out of bounds";
    }
    return index * components + component;
  }

  public function readComponent(index:Int, component:Int):T {
    return cast storage.read(flatIndex(index, component));
  }

  public function writeComponent(index:Int, component:Int, value:T):Void {
    storage.write(flatIndex(index, component), value);
  }

  public function read(index:Int):Vector<T> {
    return Vector.ofArray([for (component in 0...components) readComponent(index, component)]);
  }

  public function write(index:Int, value:Vector<T>):Void {
    if (value.length != components) {
      throw "Quadrants packed vector write length mismatch";
    }
    for (component in 0...components) {
      writeComponent(index, component, value[component]);
    }
  }

  public function toVectors():Array<Vector<T>> {
    return [for (index in 0...length) read(index)];
  }

  public function fromVectors(values:Array<Vector<T>>):Void {
    if (values.length != length) {
      throw "Quadrants packed vector value count mismatch";
    }
    for (index in 0...values.length) {
      write(index, values[index]);
    }
  }

  public function close():Void {
    storage.close();
  }

}
