package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class VectorField<T> implements TensorHandle {
  public final storage:Field<T>;
  final field:FieldRuntime;
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  public final layout:LayoutPolicy;
  public final components:Int;
  public final elementCount:Int;

  public function new(storage:Field<T>, shape:Array<Int>, components:Int, ?layout:LayoutPolicy = LayoutPolicy.Default) {
    if (storage == null) {
      throw "Quadrants VectorField requires Field storage";
    }
    var canonicalShape = checkedBatchShape(shape);
    validateComponents(components);
    var resolvedLayout = resolveLayout(layout);
    var runtime:FieldRuntime = cast storage;
    if (runtime.shape == null) {
      throw "Quadrants VectorField storage must be placed";
    }
    TensorStorage.requireSameShape(storageShape(canonicalShape, components, resolvedLayout), runtime.shape, "VectorField storage");
    this.storage = storage;
    this.field = runtime;
    this.context = runtime.context;
    this.shape = canonicalShape;
    this.dtype = runtime.dtype;
    this.layout = resolvedLayout;
    this.components = components;
    this.elementCount = TensorStorage.elementCount(canonicalShape);
  }

  public overload extern static inline function i32(context:Context, shape:Array<Int>, components:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):VectorField<I32> {
    return createI32(context, shape, components, layout);
  }

  public overload extern static inline function i32(context:Context, length:Int, components:Int):VectorField<I32> {
    return createI32(context, [length], components, LayoutPolicy.Default);
  }

  public overload extern static inline function u32(context:Context, shape:Array<Int>, components:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):VectorField<U32> {
    return createU32(context, shape, components, layout);
  }

  public overload extern static inline function u32(context:Context, length:Int, components:Int):VectorField<U32> {
    return createU32(context, [length], components, LayoutPolicy.Default);
  }

  public overload extern static inline function f32(context:Context, shape:Array<Int>, components:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):VectorField<F32> {
    return createF32(context, shape, components, layout);
  }

  public overload extern static inline function f32(context:Context, length:Int, components:Int):VectorField<F32> {
    return createF32(context, [length], components, LayoutPolicy.Default);
  }

  public overload extern static inline function f64(context:Context, shape:Array<Int>, components:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):VectorField<F64> {
    return createF64(context, shape, components, layout);
  }

  public overload extern static inline function f64(context:Context, length:Int, components:Int):VectorField<F64> {
    return createF64(context, [length], components, LayoutPolicy.Default);
  }

  public static function fromField<T>(storage:Field<T>, shape:Array<Int>, components:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):VectorField<T> {
    return new VectorField<T>(storage, shape, components, layout);
  }

  public overload extern inline function readComponent(indices:Array<Int>, component:Int):T {
    return readComponentAt(indices, component);
  }

  public overload extern inline function readComponent(index:Int, component:Int):T {
    return readComponentRankOne(index, component);
  }

  public overload extern inline function writeComponent(indices:Array<Int>, component:Int, value:T):Void {
    writeComponentAt(indices, component, value);
  }

  public overload extern inline function writeComponent(index:Int, component:Int, value:T):Void {
    writeComponentRankOne(index, component, value);
  }

  public overload extern inline function read(indices:Array<Int>):Vector<T> {
    return readAt(indices);
  }

  public overload extern inline function read(index:Int):Vector<T> {
    return readRankOne(index);
  }

  public overload extern inline function write(indices:Array<Int>, value:Vector<T>):Void {
    writeAt(indices, value);
  }

  public overload extern inline function write(index:Int, value:Vector<T>):Void {
    writeRankOne(index, value);
  }

  public function readVec2(index:Int):Vector<T> {
    requireComponents(2);
    return readRankOne(index);
  }

  public function readVec3(index:Int):Vector<T> {
    requireComponents(3);
    return readRankOne(index);
  }

  public function readVec4(index:Int):Vector<T> {
    requireComponents(4);
    return readRankOne(index);
  }

  public function writeVec2(index:Int, value:Vector<T>):Void {
    requireComponents(2);
    writeRankOne(index, value);
  }

  public function writeVec3(index:Int, value:Vector<T>):Void {
    requireComponents(3);
    writeRankOne(index, value);
  }

  public function writeVec4(index:Int, value:Vector<T>):Void {
    requireComponents(4);
    writeRankOne(index, value);
  }

  public function toVectors():Array<Vector<T>> {
    requireRankOne();
    var values = new Array<Vector<T>>();
    for (index in 0...elementCount) {
      values.push(readBatch(index));
    }
    return values;
  }

  public function fromVectors(values:Array<Vector<T>>):Void {
    requireRankOne();
    if (values.length != elementCount) {
      throw "Quadrants VectorField value count mismatch";
    }
    for (index in 0...values.length) {
      writeBatch(index, values[index]);
    }
  }

  public function lazyGrad():VectorField<T> {
    return new VectorField<T>(storage.lazyGrad(), shape, components, layout);
  }

  public function lazyDual():VectorField<T> {
    return new VectorField<T>(storage.lazyDual(), shape, components, layout);
  }

  public function nativeHandle():QNdarray {
    return field.nativeHandle();
  }

  public function close():Void {
    field.close();
  }

  static function checkedBatchShape(shape:Array<Int>):Array<Int> {
    if (shape == null) {
      throw "Quadrants VectorField requires a batch shape";
    }
    return TensorStorage.validateShape(shape);
  }

  static inline function validateComponents(components:Int):Void {
    if (components <= 0) {
      throw "Quadrants VectorField component count must be positive";
    }
  }

  static function resolveLayout(layout:LayoutPolicy):LayoutPolicy {
    if (layout == LayoutPolicy.Default) {
      return LayoutPolicy.AOS;
    }
    if (layout == LayoutPolicy.AOS || layout == LayoutPolicy.SOA) {
      return layout;
    }
    throw "Quadrants VectorField layout must be AOS or SOA";
  }

  static function storageShape(shape:Array<Int>, components:Int, layout:LayoutPolicy):Array<Int> {
    validateComponents(components);
    var physicalShape = checkedBatchShape(shape);
    if (layout == LayoutPolicy.AOS) {
      physicalShape.push(components);
      return physicalShape;
    }
    if (layout == LayoutPolicy.SOA) {
      physicalShape.unshift(components);
      return physicalShape;
    }
    throw "Quadrants VectorField layout must be AOS or SOA";
  }

  static function createI32(context:Context, shape:Array<Int>, components:Int, layout:LayoutPolicy):VectorField<I32> {
    var resolvedLayout = resolveLayout(layout);
    return new VectorField<I32>(new Field<I32>(context, storageShape(shape, components, resolvedLayout)), shape, components, resolvedLayout);
  }

  static function createU32(context:Context, shape:Array<Int>, components:Int, layout:LayoutPolicy):VectorField<U32> {
    var resolvedLayout = resolveLayout(layout);
    return new VectorField<U32>(new Field<U32>(context, storageShape(shape, components, resolvedLayout)), shape, components, resolvedLayout);
  }

  static function createF32(context:Context, shape:Array<Int>, components:Int, layout:LayoutPolicy):VectorField<F32> {
    var resolvedLayout = resolveLayout(layout);
    return new VectorField<F32>(new Field<F32>(context, storageShape(shape, components, resolvedLayout)), shape, components, resolvedLayout);
  }

  static function createF64(context:Context, shape:Array<Int>, components:Int, layout:LayoutPolicy):VectorField<F64> {
    var resolvedLayout = resolveLayout(layout);
    return new VectorField<F64>(new Field<F64>(context, storageShape(shape, components, resolvedLayout)), shape, components, resolvedLayout);
  }

  inline function requireComponents(expected:Int):Void {
    if (components != expected) {
      throw "Quadrants VectorField component count mismatch";
    }
  }

  inline function requireRankOne():Void {
    if (shape.length != 1) {
      throw "Quadrants VectorField rank-1 indexing requires a one-dimensional batch shape";
    }
  }

  inline function rankOneBatchIndex(index:Int):Int {
    requireRankOne();
    if (index < 0 || index >= elementCount) {
      throw "Quadrants VectorField index out of bounds";
    }
    return index;
  }

  inline function scalarIndex(indices:Array<Int>, component:Int):Int {
    return scalarIndexFromBatchFlat(TensorStorage.flatIndex(shape, indices), component);
  }

  inline function scalarIndexFromBatchFlat(batchFlat:Int, component:Int):Int {
    if (component < 0 || component >= components) {
      throw "Quadrants VectorField component out of bounds";
    }
    return layout == LayoutPolicy.AOS
      ? batchFlat * components + component
      : component * elementCount + batchFlat;
  }

  inline function readComponentAt(indices:Array<Int>, component:Int):T {
    return cast storage.read(scalarIndex(indices, component));
  }

  inline function readComponentRankOne(index:Int, component:Int):T {
    return cast storage.read(scalarIndexFromBatchFlat(rankOneBatchIndex(index), component));
  }

  inline function writeComponentAt(indices:Array<Int>, component:Int, value:T):Void {
    storage.write(scalarIndex(indices, component), value);
  }

  inline function writeComponentRankOne(index:Int, component:Int, value:T):Void {
    storage.write(scalarIndexFromBatchFlat(rankOneBatchIndex(index), component), value);
  }

  inline function readAt(indices:Array<Int>):Vector<T> {
    return readBatch(TensorStorage.flatIndex(shape, indices));
  }

  inline function readRankOne(index:Int):Vector<T> {
    return readBatch(rankOneBatchIndex(index));
  }

  inline function readBatch(batchFlat:Int):Vector<T> {
    var values = new Array<T>();
    for (component in 0...components) {
      values.push(cast storage.read(scalarIndexFromBatchFlat(batchFlat, component)));
    }
    return Vector.ofArray(values);
  }

  inline function writeAt(indices:Array<Int>, value:Vector<T>):Void {
    writeBatch(TensorStorage.flatIndex(shape, indices), value);
  }

  inline function writeRankOne(index:Int, value:Vector<T>):Void {
    writeBatch(rankOneBatchIndex(index), value);
  }

  inline function writeBatch(batchFlat:Int, value:Vector<T>):Void {
    if (value.length != components) {
      throw "Quadrants VectorField write length mismatch";
    }
    for (component in 0...components) {
      storage.write(scalarIndexFromBatchFlat(batchFlat, component), value[component]);
    }
  }
}
