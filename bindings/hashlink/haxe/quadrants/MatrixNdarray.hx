package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class MatrixNdarray<T> implements TensorHandle {
  public final storage:Tensor<T>;
  final handle:TensorHandle;
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  public final layout:LayoutPolicy;
  public final rows:Int;
  public final cols:Int;
  public final elementCount:Int;
  final laneCount:Int;

  public function new(storage:Tensor<T>, shape:Array<Int>, rows:Int, cols:Int, ?layout:LayoutPolicy = LayoutPolicy.Default) {
    if (storage == null) {
      throw "Quadrants MatrixNdarray requires Tensor storage";
    }
    var canonicalShape = checkedBatchShape(shape);
    var lanes = matrixLaneCount(rows, cols);
    var resolvedLayout = resolveLayout(layout);
    var runtime:TensorRuntime = cast storage;
    TensorStorage.requireSameShape(storageShape(canonicalShape, lanes, resolvedLayout), runtime.shape, "MatrixNdarray storage");
    this.storage = storage;
    this.handle = runtime;
    this.context = runtime.context;
    this.shape = canonicalShape;
    this.dtype = runtime.dtype;
    this.layout = resolvedLayout;
    this.rows = rows;
    this.cols = cols;
    this.elementCount = TensorStorage.elementCount(canonicalShape);
    this.laneCount = lanes;
  }

  public overload extern static inline function i32(context:Context, shape:Array<Int>, rows:Int, cols:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):MatrixNdarray<I32> {
    return createI32(context, shape, rows, cols, layout);
  }

  public overload extern static inline function i32(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<I32> {
    return createI32(context, [length], rows, cols, LayoutPolicy.Default);
  }

  public overload extern static inline function u32(context:Context, shape:Array<Int>, rows:Int, cols:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):MatrixNdarray<U32> {
    return createU32(context, shape, rows, cols, layout);
  }

  public overload extern static inline function u32(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<U32> {
    return createU32(context, [length], rows, cols, LayoutPolicy.Default);
  }

  public overload extern static inline function f32(context:Context, shape:Array<Int>, rows:Int, cols:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):MatrixNdarray<F32> {
    return createF32(context, shape, rows, cols, layout);
  }

  public overload extern static inline function f32(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<F32> {
    return createF32(context, [length], rows, cols, LayoutPolicy.Default);
  }

  public overload extern static inline function f64(context:Context, shape:Array<Int>, rows:Int, cols:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):MatrixNdarray<F64> {
    return createF64(context, shape, rows, cols, layout);
  }

  public overload extern static inline function f64(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<F64> {
    return createF64(context, [length], rows, cols, LayoutPolicy.Default);
  }

  public static function fromTensor<T>(storage:Tensor<T>, shape:Array<Int>, rows:Int, cols:Int, ?layout:LayoutPolicy = LayoutPolicy.Default):MatrixNdarray<T> {
    return new MatrixNdarray<T>(storage, shape, rows, cols, layout);
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

  public overload extern inline function readElement(indices:Array<Int>, row:Int, col:Int):T {
    return readElementAt(indices, row, col);
  }

  public overload extern inline function readElement(index:Int, row:Int, col:Int):T {
    return readElementRankOne(index, row, col);
  }

  public overload extern inline function writeElement(indices:Array<Int>, row:Int, col:Int, value:T):Void {
    writeElementAt(indices, row, col, value);
  }

  public overload extern inline function writeElement(index:Int, row:Int, col:Int, value:T):Void {
    writeElementRankOne(index, row, col, value);
  }

  public overload extern inline function read(indices:Array<Int>):Matrix<T> {
    return readAt(indices);
  }

  public overload extern inline function read(index:Int):Matrix<T> {
    return readRankOne(index);
  }

  public overload extern inline function write(indices:Array<Int>, value:Matrix<T>):Void {
    writeAt(indices, value);
  }

  public overload extern inline function write(index:Int, value:Matrix<T>):Void {
    writeRankOne(index, value);
  }

  public function readMat2(index:Int):Matrix<T> {
    requireShape(2, 2);
    return readRankOne(index);
  }

  public function readMat3(index:Int):Matrix<T> {
    requireShape(3, 3);
    return readRankOne(index);
  }

  public function readMat4(index:Int):Matrix<T> {
    requireShape(4, 4);
    return readRankOne(index);
  }

  public function writeMat2(index:Int, value:Matrix<T>):Void {
    requireShape(2, 2);
    writeRankOne(index, value);
  }

  public function writeMat3(index:Int, value:Matrix<T>):Void {
    requireShape(3, 3);
    writeRankOne(index, value);
  }

  public function writeMat4(index:Int, value:Matrix<T>):Void {
    requireShape(4, 4);
    writeRankOne(index, value);
  }

  public function toMatrices():Array<Matrix<T>> {
    requireRankOne();
    var values = new Array<Matrix<T>>();
    for (index in 0...elementCount) {
      values.push(readBatch(index));
    }
    return values;
  }

  public function fromMatrices(values:Array<Matrix<T>>):Void {
    requireRankOne();
    if (values.length != elementCount) {
      throw "Quadrants MatrixNdarray value count mismatch";
    }
    for (index in 0...values.length) {
      writeBatch(index, values[index]);
    }
  }

  public function nativeHandle():QNdarray {
    return handle.nativeHandle();
  }

  public function close():Void {
    handle.close();
  }

  static function checkedBatchShape(shape:Array<Int>):Array<Int> {
    if (shape == null) {
      throw "Quadrants MatrixNdarray requires a batch shape";
    }
    return TensorStorage.validateShape(shape);
  }

  static function matrixLaneCount(rows:Int, cols:Int):Int {
    if (rows <= 0 || cols <= 0) {
      throw "Quadrants MatrixNdarray dimensions must be positive";
    }
    var lanes = TensorStorage.elementCount([rows, cols]);
    if (lanes <= 0) {
      throw "Quadrants MatrixNdarray matrix size overflow";
    }
    return lanes;
  }

  static function resolveLayout(layout:LayoutPolicy):LayoutPolicy {
    if (layout == LayoutPolicy.Default) {
      return LayoutPolicy.AOS;
    }
    if (layout == LayoutPolicy.AOS || layout == LayoutPolicy.SOA) {
      return layout;
    }
    throw "Quadrants MatrixNdarray layout must be AOS or SOA";
  }

  static function storageShape(shape:Array<Int>, lanes:Int, layout:LayoutPolicy):Array<Int> {
    if (lanes <= 0) {
      throw "Quadrants MatrixNdarray matrix size must be positive";
    }
    var physicalShape = checkedBatchShape(shape);
    if (layout == LayoutPolicy.AOS) {
      physicalShape.push(lanes);
      return physicalShape;
    }
    if (layout == LayoutPolicy.SOA) {
      physicalShape.unshift(lanes);
      return physicalShape;
    }
    throw "Quadrants MatrixNdarray layout must be AOS or SOA";
  }

  static function createI32(context:Context, shape:Array<Int>, rows:Int, cols:Int, layout:LayoutPolicy):MatrixNdarray<I32> {
    var lanes = matrixLaneCount(rows, cols);
    var resolvedLayout = resolveLayout(layout);
    return new MatrixNdarray<I32>(new Tensor<I32>(context, storageShape(shape, lanes, resolvedLayout)), shape, rows, cols, resolvedLayout);
  }

  static function createU32(context:Context, shape:Array<Int>, rows:Int, cols:Int, layout:LayoutPolicy):MatrixNdarray<U32> {
    var lanes = matrixLaneCount(rows, cols);
    var resolvedLayout = resolveLayout(layout);
    return new MatrixNdarray<U32>(new Tensor<U32>(context, storageShape(shape, lanes, resolvedLayout)), shape, rows, cols, resolvedLayout);
  }

  static function createF32(context:Context, shape:Array<Int>, rows:Int, cols:Int, layout:LayoutPolicy):MatrixNdarray<F32> {
    var lanes = matrixLaneCount(rows, cols);
    var resolvedLayout = resolveLayout(layout);
    return new MatrixNdarray<F32>(new Tensor<F32>(context, storageShape(shape, lanes, resolvedLayout)), shape, rows, cols, resolvedLayout);
  }

  static function createF64(context:Context, shape:Array<Int>, rows:Int, cols:Int, layout:LayoutPolicy):MatrixNdarray<F64> {
    var lanes = matrixLaneCount(rows, cols);
    var resolvedLayout = resolveLayout(layout);
    return new MatrixNdarray<F64>(new Tensor<F64>(context, storageShape(shape, lanes, resolvedLayout)), shape, rows, cols, resolvedLayout);
  }

  inline function requireShape(expectedRows:Int, expectedCols:Int):Void {
    if (rows != expectedRows || cols != expectedCols) {
      throw "Quadrants MatrixNdarray shape mismatch";
    }
  }

  inline function requireRankOne():Void {
    if (shape.length != 1) {
      throw "Quadrants MatrixNdarray rank-1 indexing requires a one-dimensional batch shape";
    }
  }

  inline function rankOneBatchIndex(index:Int):Int {
    requireRankOne();
    if (index < 0 || index >= elementCount) {
      throw "Quadrants MatrixNdarray index out of bounds";
    }
    return index;
  }

  inline function componentIndex(row:Int, col:Int):Int {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw "Quadrants MatrixNdarray matrix element out of bounds";
    }
    return row * cols + col;
  }

  inline function scalarIndex(indices:Array<Int>, component:Int):Int {
    return scalarIndexFromBatchFlat(TensorStorage.flatIndex(shape, indices), component);
  }

  inline function scalarIndexFromBatchFlat(batchFlat:Int, component:Int):Int {
    if (component < 0 || component >= laneCount) {
      throw "Quadrants MatrixNdarray component out of bounds";
    }
    return layout == LayoutPolicy.AOS
      ? batchFlat * laneCount + component
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

  inline function readElementAt(indices:Array<Int>, row:Int, col:Int):T {
    return cast storage.read(scalarIndex(indices, componentIndex(row, col)));
  }

  inline function readElementRankOne(index:Int, row:Int, col:Int):T {
    return cast storage.read(scalarIndexFromBatchFlat(rankOneBatchIndex(index), componentIndex(row, col)));
  }

  inline function writeElementAt(indices:Array<Int>, row:Int, col:Int, value:T):Void {
    storage.write(scalarIndex(indices, componentIndex(row, col)), value);
  }

  inline function writeElementRankOne(index:Int, row:Int, col:Int, value:T):Void {
    storage.write(scalarIndexFromBatchFlat(rankOneBatchIndex(index), componentIndex(row, col)), value);
  }

  inline function readAt(indices:Array<Int>):Matrix<T> {
    return readBatch(TensorStorage.flatIndex(shape, indices));
  }

  inline function readRankOne(index:Int):Matrix<T> {
    return readBatch(rankOneBatchIndex(index));
  }

  inline function readBatch(batchFlat:Int):Matrix<T> {
    var values = new Array<T>();
    for (component in 0...laneCount) {
      values.push(cast storage.read(scalarIndexFromBatchFlat(batchFlat, component)));
    }
    return Matrix.ofArray(rows, cols, values);
  }

  inline function writeAt(indices:Array<Int>, value:Matrix<T>):Void {
    writeBatch(TensorStorage.flatIndex(shape, indices), value);
  }

  inline function writeRankOne(index:Int, value:Matrix<T>):Void {
    writeBatch(rankOneBatchIndex(index), value);
  }

  inline function writeBatch(batchFlat:Int, value:Matrix<T>):Void {
    if (value.rows != rows || value.cols != cols) {
      throw "Quadrants MatrixNdarray write shape mismatch";
    }
    var component = 0;
    for (row in 0...rows) {
      for (col in 0...cols) {
        storage.write(scalarIndexFromBatchFlat(batchFlat, component), value.get(row, col));
        component++;
      }
    }
  }
}
