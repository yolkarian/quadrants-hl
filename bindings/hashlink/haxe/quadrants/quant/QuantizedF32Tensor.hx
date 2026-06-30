package quadrants.quant;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.TensorStorage;
import quadrants.Types.F32;
import quadrants.Types.I32;

class QuantizedF32Tensor {
  public final context:Context;
  public final shape:Array<Int>;
  public final spec:QuantStorageSpec<F32>;
  public final storage:Tensor<I32>;
  final scale:Float;
  final minRaw:Int;
  final maxRaw:Int;

  public function new(context:Context, shape:Array<Int>, spec:QuantStorageSpec<F32>) {
    if (context == null) {
      throw "Quadrants quantized tensor requires a Context";
    }
    if (spec == null) {
      throw "Quadrants quantized tensor requires a quant storage spec";
    }
    this.context = context;
    this.shape = TensorStorage.validateShape(shape);
    this.spec = spec;
    this.storage = new Tensor<I32>(context, this.shape);
    scale = Math.pow(2.0, spec.fractionalBits);
    var bitCount:Int = spec.bits;
    if (spec.signed) {
      minRaw = -Std.int(Math.pow(2.0, bitCount - 1));
      maxRaw = Std.int(Math.pow(2.0, bitCount - 1)) - 1;
    } else {
      minRaw = 0;
      maxRaw = Std.int(Math.pow(2.0, bitCount)) - 1;
    }
  }

  public function elementCount():Int {
    return storage.elementCount();
  }

  public function readRaw(flatIndex:Int):I32 {
    return storage.read(flatIndex);
  }

  public function writeRaw(flatIndex:Int, value:I32):Void {
    var raw:Int = value;
    if (raw < minRaw || raw > maxRaw) {
      throw "Quadrants quantized raw value is outside storage range";
    }
    storage.write(flatIndex, value);
  }

  public function read(flatIndex:Int):F32 {
    return storage.read(flatIndex) / scale;
  }

  public function write(flatIndex:Int, value:F32):Void {
    var raw = Std.int(Math.round((value : Float) * scale));
    if (raw < minRaw) raw = minRaw;
    if (raw > maxRaw) raw = maxRaw;
    storage.write(flatIndex, raw);
  }

  @:noCompletion public inline function __qdQuantStorage():Tensor<I32> {
    return storage;
  }

  @:noCompletion public inline function __qdQuantScale():Float {
    return scale;
  }

  @:noCompletion public inline function __qdQuantMinRaw():Int {
    return minRaw;
  }

  @:noCompletion public inline function __qdQuantMaxRaw():Int {
    return maxRaw;
  }

  public function close():Void {
    storage.close();
  }
}
