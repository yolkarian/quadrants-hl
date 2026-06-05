package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;
import quadrants.packed.PackedMatrixTensor;

class MatrixNdarray<T> implements TensorHandle {
  public final storage:Tensor<T>;
  final handle:TensorHandle;
  public final context:Context;
  public final shape:Array<Int>;
  public final dtype:DType;
  public final rows:Int;
  public final cols:Int;
  public final length:Int;

  public function new(storage:Tensor<T>, rows:Int, cols:Int) {
    if (rows <= 0 || cols <= 0 || rows > 4 || cols > 4) {
      throw "Quadrants MatrixNdarray dimensions must be in 1...4";
    }
    var runtime:TensorRuntime = cast storage;
    if (runtime.shape == null || runtime.shape.length != 1) {
      throw "Quadrants MatrixNdarray storage must be a flat one-dimensional Tensor";
    }
    var components = rows * cols;
    var elementCount = quadrants.TensorStorage.elementCount(runtime.shape);
    if (elementCount % components != 0) {
      throw "Quadrants MatrixNdarray element count must be divisible by matrix size";
    }
    this.storage = storage;
    this.handle = runtime;
    this.context = runtime.context;
    this.shape = runtime.shape;
    this.dtype = runtime.dtype;
    this.rows = rows;
    this.cols = cols;
    this.length = Std.int(elementCount / components);
  }

  public static function i32(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<I32> {
    return new MatrixNdarray<I32>(new Tensor<I32>(context, [length * rows * cols]), rows, cols);
  }

  public static function u32(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<U32> {
    return new MatrixNdarray<U32>(new Tensor<U32>(context, [length * rows * cols]), rows, cols);
  }

  public static function f32(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<F32> {
    return new MatrixNdarray<F32>(new Tensor<F32>(context, [length * rows * cols]), rows, cols);
  }

  public static function f64(context:Context, length:Int, rows:Int, cols:Int):MatrixNdarray<F64> {
    return new MatrixNdarray<F64>(new Tensor<F64>(context, [length * rows * cols]), rows, cols);
  }

  public static function fromTensor<T>(storage:Tensor<T>, rows:Int, cols:Int):MatrixNdarray<T> {
    return new MatrixNdarray<T>(storage, rows, cols);
  }

  public static function fromPacked<T>(packed:PackedMatrixTensor<T>):MatrixNdarray<T> {
    return new MatrixNdarray<T>(packed.storage, packed.rows, packed.cols);
  }

  public function toPacked():PackedMatrixTensor<T> {
    return PackedMatrixTensor.fromTensor(storage, rows, cols);
  }

  inline function requireShape(expectedRows:Int, expectedCols:Int):Void {
    if (rows != expectedRows || cols != expectedCols) {
      throw "Quadrants MatrixNdarray shape mismatch";
    }
  }

  inline function flatIndex(index:Int, row:Int, col:Int):Int {
    if (index < 0 || index >= length) {
      throw "Quadrants MatrixNdarray index out of bounds";
    }
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw "Quadrants MatrixNdarray component out of bounds";
    }
    return (index * rows + row) * cols + col;
  }

  public function readElement(index:Int, row:Int, col:Int):T {
    return cast storage.read(flatIndex(index, row, col));
  }

  public function writeElement(index:Int, row:Int, col:Int, value:T):Void {
    storage.write(flatIndex(index, row, col), value);
  }

  public function read(index:Int):Matrix<T> {
    return Matrix.ofArray(rows, cols, [for (row in 0...rows) for (col in 0...cols) readElement(index, row, col)]);
  }

  public function write(index:Int, value:Matrix<T>):Void {
    if (value.rows != rows || value.cols != cols) {
      throw "Quadrants MatrixNdarray write shape mismatch";
    }
    for (row in 0...rows) {
      for (col in 0...cols) {
        writeElement(index, row, col, value.get(row, col));
      }
    }
  }

  public function readMat2(index:Int):Matrix<T> {
    requireShape(2, 2);
    return read(index);
  }

  public function readMat3(index:Int):Matrix<T> {
    requireShape(3, 3);
    return read(index);
  }

  public function readMat4(index:Int):Matrix<T> {
    requireShape(4, 4);
    return read(index);
  }

  public function writeMat2(index:Int, value:Matrix<T>):Void {
    requireShape(2, 2);
    write(index, value);
  }

  public function writeMat3(index:Int, value:Matrix<T>):Void {
    requireShape(3, 3);
    write(index, value);
  }

  public function writeMat4(index:Int, value:Matrix<T>):Void {
    requireShape(4, 4);
    write(index, value);
  }

  public function toMatrices():Array<Matrix<T>> {
    return [for (index in 0...length) read(index)];
  }

  public function fromMatrices(values:Array<Matrix<T>>):Void {
    if (values.length != length) {
      throw "Quadrants MatrixNdarray value count mismatch";
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
