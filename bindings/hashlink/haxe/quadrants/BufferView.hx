package quadrants;

class BufferView<T> {
  public final tensor:TensorRuntime;
  public final flatStart:Int;
  public final length:Int;
  final reader:Int->T;
  final writer:(Int, T)->Void;

  public function new(tensor:TensorRuntime, flatStart:Int, length:Int, reader:Int->T, writer:(Int, T)->Void) {
    if (flatStart < 0) {
      throw "Quadrants BufferView flat start must be non-negative";
    }
    if (length < 0) {
      throw "Quadrants BufferView length must be non-negative";
    }
    if (flatStart > tensor.elementCount() || length > tensor.elementCount() - flatStart) {
      throw "Quadrants BufferView range is out of bounds";
    }
    this.tensor = tensor;
    this.flatStart = flatStart;
    this.length = length;
    this.reader = reader;
    this.writer = writer;
  }

  inline function offset(index:Int):Int {
    if (index < 0 || index >= length) {
      throw "Quadrants BufferView index out of bounds";
    }
    return flatStart + index;
  }

  public function shape(axis:Int):Int {
    if (axis != 0) {
      throw "Quadrants BufferView only has one dimension";
    }
    return length;
  }

  public function copyToBytes(out:hl.Bytes, count:Int = -1, outByteOffset:Int = 0):Void {
    tensor.copyToBytes(out, flatStart, count < 0 ? length : count, outByteOffset);
  }

  public function copyFromBytes(input:hl.Bytes, count:Int = -1, inputByteOffset:Int = 0):Void {
    tensor.copyFromBytes(input, flatStart, count < 0 ? length : count, inputByteOffset);
  }

  public function read(index:Int):T return reader(offset(index));
  public function write(index:Int, value:T):Void writer(offset(index), value);
}
