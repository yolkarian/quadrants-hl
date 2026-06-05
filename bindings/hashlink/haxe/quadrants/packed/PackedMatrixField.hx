package quadrants.packed;

import quadrants.Context;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.Matrix;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class PackedMatrixField<T> {
  public final storage:Field<T>;
  public final context:Context;
  public final rows:Int;
  public final cols:Int;
  public final length:Int;

  public function new(storage:Field<T>, rows:Int, cols:Int) {
    if (rows <= 0 || cols <= 0 || rows > 4 || cols > 4) {
      throw "Quadrants packed matrix dimensions must be in 1...4";
    }
    var runtime:FieldRuntime = cast storage;
    var components = rows * cols;
    if (runtime.shape == null || runtime.shape.length == 0) {
      throw "Quadrants packed matrix field requires storage elements";
    }
    if (runtime.elementCount() % components != 0) {
      throw "Quadrants packed matrix field element count must be divisible by matrix size";
    }
    if (runtime.shape.length > 2 && (runtime.shape[runtime.shape.length - 2] != rows || runtime.shape[runtime.shape.length - 1] != cols)) {
      throw "Quadrants packed matrix field trailing dimensions must match matrix shape";
    }
    this.storage = storage;
    this.context = runtime.context;
    this.rows = rows;
    this.cols = cols;
    this.length = Std.int(runtime.elementCount() / (rows * cols));
  }

  public static function i32(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixField<I32> {
    return new PackedMatrixField<I32>(new Field<I32>(context, [length * rows * cols]), rows, cols);
  }

  public static function u32(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixField<U32> {
    return new PackedMatrixField<U32>(new Field<U32>(context, [length * rows * cols]), rows, cols);
  }

  public static function f32(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixField<F32> {
    return new PackedMatrixField<F32>(new Field<F32>(context, [length * rows * cols]), rows, cols);
  }

  public static function f64(context:Context, length:Int, rows:Int, cols:Int):PackedMatrixField<F64> {
    return new PackedMatrixField<F64>(new Field<F64>(context, [length * rows * cols]), rows, cols);
  }

  public static function fromField<T>(storage:Field<T>, rows:Int, cols:Int):PackedMatrixField<T> {
    return new PackedMatrixField<T>(storage, rows, cols);
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

}
