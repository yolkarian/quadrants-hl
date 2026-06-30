package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class VectorNdarray<T> implements TensorHandle {
  public final storage:Tensor<T>;
  final handle:TensorHandle;
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  public final components:Int;
  public final length:Int;

  public function new(storage:Tensor<T>, components:Int) {
    if (components <= 0 || components > 4) {
      throw "Quadrants VectorNdarray component count must be in 1...4";
    }
    var runtime:TensorRuntime = cast storage;
    if (runtime.shape == null || runtime.shape.length != 1) {
      throw "Quadrants VectorNdarray storage must be a flat one-dimensional Tensor";
    }
    var elementCount = quadrants.TensorStorage.elementCount(runtime.shape);
    if (elementCount % components != 0) {
      throw "Quadrants VectorNdarray element count must be divisible by component count";
    }
    this.storage = storage;
    this.handle = runtime;
    this.context = runtime.context;
    this.shape = runtime.shape;
    this.dtype = runtime.dtype;
    this.components = components;
    this.length = Std.int(elementCount / components);
  }

  public static function i32(context:Context, length:Int, components:Int):VectorNdarray<I32> {
    return new VectorNdarray<I32>(new Tensor<I32>(context, [length * components]), components);
  }

  public static function u32(context:Context, length:Int, components:Int):VectorNdarray<U32> {
    return new VectorNdarray<U32>(new Tensor<U32>(context, [length * components]), components);
  }

  public static function f32(context:Context, length:Int, components:Int):VectorNdarray<F32> {
    return new VectorNdarray<F32>(new Tensor<F32>(context, [length * components]), components);
  }

  public static function f64(context:Context, length:Int, components:Int):VectorNdarray<F64> {
    return new VectorNdarray<F64>(new Tensor<F64>(context, [length * components]), components);
  }

  public static function fromTensor<T>(storage:Tensor<T>, components:Int):VectorNdarray<T> {
    return new VectorNdarray<T>(storage, components);
  }


  inline function requireComponents(expected:Int):Void {
    if (components != expected) {
      throw "Quadrants VectorNdarray component count mismatch";
    }
  }

  inline function flatIndex(index:Int, component:Int):Int {
    if (index < 0 || index >= length) {
      throw "Quadrants VectorNdarray index out of bounds";
    }
    if (component < 0 || component >= components) {
      throw "Quadrants VectorNdarray component out of bounds";
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
      throw "Quadrants VectorNdarray write length mismatch";
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
      throw "Quadrants VectorNdarray value count mismatch";
    }
    for (index in 0...values.length) {
      write(index, values[index]);
    }
  }

  public function syncBeforeKernel():Void {}

  public function syncAfterKernel():Void {}

  public function nativeHandle():QNdarray {
    return handle.nativeHandle();
  }

  public function close():Void {
    handle.close();
  }

}
