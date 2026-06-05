package quadrants.packed;

import quadrants.Context;
import quadrants.Matrix;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class PackedMatrixTensor<T> {
  public final storage:Dynamic;
  public final context:Context;
  public final rows:Int;
  public final cols:Int;
  public final length:Int;

  public function new(storage:Dynamic, rows:Int, cols:Int) {
    if (rows <= 0 || cols <= 0 || rows > 4 || cols > 4) {
      throw "Quadrants packed matrix dimensions must be in 1...4";
    }
    var runtime = requireTensor(storage);
    var components = rows * cols;
    if (runtime.shape.length == 0) {
      throw "Quadrants packed matrix tensor requires storage elements";
    }
    if (runtime.elementCount() % components != 0) {
      throw "Quadrants packed matrix tensor element count must be divisible by matrix size";
    }
    if (runtime.shape.length > 2 && (runtime.shape[runtime.shape.length - 2] != rows || runtime.shape[runtime.shape.length - 1] != cols)) {
      throw "Quadrants packed matrix tensor trailing dimensions must match matrix shape";
    }
    this.storage = storage;
    this.context = runtime.context;
    this.rows = rows;
    this.cols = cols;
    this.length = Std.int(runtime.elementCount() / (rows * cols));
  }

  public static function i32(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixTensor<I32> {
    return new PackedMatrixTensor<I32>(new Tensor<I32>(context, [length * rows * cols]), rows, cols);
  }

  public static function u32(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixTensor<U32> {
    return new PackedMatrixTensor<U32>(new Tensor<U32>(context, [length * rows * cols]), rows, cols);
  }

  public static function f32(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixTensor<F32> {
    return new PackedMatrixTensor<F32>(new Tensor<F32>(context, [length * rows * cols]), rows, cols);
  }

  public static function f64(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixTensor<F64> {
    return new PackedMatrixTensor<F64>(new Tensor<F64>(context, [length * rows * cols]), rows, cols);
  }

  public static function fromTensor<T>(storage:Dynamic, rows:Int, cols:Int):PackedMatrixTensor<T> {
    return new PackedMatrixTensor<T>(storage, rows, cols);
  }

  inline function flatIndex(index:Int, row:Int, col:Int):Int {
    if (index < 0 || index >= length) {
      throw "Quadrants packed matrix index out of bounds";
    }
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw "Quadrants packed matrix component out of bounds";
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
      throw "Quadrants packed matrix write shape mismatch";
    }
    for (row in 0...rows) {
      for (col in 0...cols) {
        writeElement(index, row, col, value.get(row, col));
      }
    }
  }

  public function toMatrices():Array<Matrix<T>> {
    return [for (index in 0...length) read(index)];
  }

  public function fromMatrices(values:Array<Matrix<T>>):Void {
    if (values.length != length) {
      throw "Quadrants packed matrix value count mismatch";
    }
    for (index in 0...values.length) {
      write(index, values[index]);
    }
  }

  public function close():Void {
    storage.close();
  }

  static function requireTensor(value:Dynamic):TensorRuntime {
    if (!Std.isOfType(value, TensorRuntime)) {
      throw "Quadrants packed matrix storage must be a Tensor";
    }
    return cast value;
  }
}
