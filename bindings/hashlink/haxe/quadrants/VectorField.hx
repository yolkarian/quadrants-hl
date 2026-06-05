package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;
import quadrants.packed.PackedVectorField;

class VectorField<T> implements TensorHandle {
  public final storage:Field<T>;
  final field:FieldRuntime;
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  public final components:Int;
  public final length:Int;

  public function new(storage:Field<T>, components:Int) {
    if (components <= 0 || components > 4) {
      throw "Quadrants VectorField component count must be in 1...4";
    }
    var runtime:FieldRuntime = cast storage;
    if (runtime.shape == null || runtime.shape.length != 1) {
      throw "Quadrants VectorField storage must be a placed flat one-dimensional Field";
    }
    var elementCount = runtime.elementCount();
    if (elementCount % components != 0) {
      throw "Quadrants VectorField element count must be divisible by component count";
    }
    this.storage = storage;
    this.field = runtime;
    this.context = runtime.context;
    this.shape = runtime.shape;
    this.dtype = runtime.dtype;
    this.components = components;
    this.length = Std.int(elementCount / components);
  }

  public static function i32(context:Context, length:Int, components:Int):VectorField<I32> {
    return new VectorField<I32>(new Field<I32>(context, [length * components]), components);
  }

  public static function u32(context:Context, length:Int, components:Int):VectorField<U32> {
    return new VectorField<U32>(new Field<U32>(context, [length * components]), components);
  }

  public static function f32(context:Context, length:Int, components:Int):VectorField<F32> {
    return new VectorField<F32>(new Field<F32>(context, [length * components]), components);
  }

  public static function f64(context:Context, length:Int, components:Int):VectorField<F64> {
    return new VectorField<F64>(new Field<F64>(context, [length * components]), components);
  }

  public static function fromField<T>(storage:Field<T>, components:Int):VectorField<T> {
    return new VectorField<T>(storage, components);
  }

  public static function fromPacked<T>(packed:PackedVectorField<T>):VectorField<T> {
    return new VectorField<T>(packed.storage, packed.components);
  }

  public function toPacked():PackedVectorField<T> {
    return PackedVectorField.fromField(storage, components);
  }

  inline function requireComponents(expected:Int):Void {
    if (components != expected) {
      throw "Quadrants VectorField component count mismatch";
    }
  }

  inline function flatIndex(index:Int, component:Int):Int {
    if (index < 0 || index >= length) {
      throw "Quadrants VectorField index out of bounds";
    }
    if (component < 0 || component >= components) {
      throw "Quadrants VectorField component out of bounds";
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
      throw "Quadrants VectorField write length mismatch";
    }
    for (component in 0...components) {
      writeComponent(index, component, value[component]);
    }
  }

  public function readVec2(index:Int):Vector<T> {
    requireComponents(2);
    return read(index);
  }

  public function readVec3(index:Int):Vector<T> {
    requireComponents(3);
    return read(index);
  }

  public function readVec4(index:Int):Vector<T> {
    requireComponents(4);
    return read(index);
  }

  public function writeVec2(index:Int, value:Vector<T>):Void {
    requireComponents(2);
    write(index, value);
  }

  public function writeVec3(index:Int, value:Vector<T>):Void {
    requireComponents(3);
    write(index, value);
  }

  public function writeVec4(index:Int, value:Vector<T>):Void {
    requireComponents(4);
    write(index, value);
  }

  public function toVectors():Array<Vector<T>> {
    return [for (index in 0...length) read(index)];
  }

  public function fromVectors(values:Array<Vector<T>>):Void {
    if (values.length != length) {
      throw "Quadrants VectorField value count mismatch";
    }
    for (index in 0...values.length) {
      write(index, values[index]);
    }
  }

  public function lazyGrad():VectorField<T> {
    return new VectorField<T>(storage.lazyGrad(), components);
  }

  public function lazyDual():VectorField<T> {
    return new VectorField<T>(storage.lazyDual(), components);
  }

  public function syncBeforeKernel():Void {
    field.syncSNodeToTensor();
    field.syncAutodiffPeersToTensor();
  }

  public function syncAfterKernel():Void {
    field.syncTensorToSNode();
    field.syncAutodiffPeersFromTensor();
  }

  public function nativeHandle():QNdarray {
    return field.nativeHandle();
  }

  public function close():Void {
    field.close();
  }

}
