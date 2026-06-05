package quadrants.algorithms;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;

class Scratch {
  public final context:Context;
  var i32Tensor:Tensor<I32> = null;
  var f32Tensor:Tensor<F32> = null;
  var i32Capacity:Int = 0;
  var f32Capacity:Int = 0;
  var closed:Bool = false;

  public function new(context:Context) {
    if (context == null) {
      throw "Quadrants scratch context is required";
    }
    this.context = context;
  }

  public function i32(count:Int):Tensor<I32> {
    requireOpen();
    var capacity = requestedCapacity(count);
    if (i32Tensor == null || i32Capacity < capacity) {
      if (i32Tensor != null) {
        i32Tensor.close();
      }
      i32Tensor = new Tensor<I32>(context, [capacity]);
      i32Capacity = capacity;
    }
    return i32Tensor;
  }

  public function f32(count:Int):Tensor<F32> {
    requireOpen();
    var capacity = requestedCapacity(count);
    if (f32Tensor == null || f32Capacity < capacity) {
      if (f32Tensor != null) {
        f32Tensor.close();
      }
      f32Tensor = new Tensor<F32>(context, [capacity]);
      f32Capacity = capacity;
    }
    return f32Tensor;
  }

  public function reset():Void {
    requireOpen();
    // One whole tensor per dtype is retained for reuse; only close() releases storage.
  }

  public function close():Void {
    if (!closed) {
      closeOwnedTensors();
      closed = true;
    }
  }

  function requireOpen():Void {
    if (closed) {
      throw "Quadrants scratch is closed";
    }
  }

  static function requestedCapacity(count:Int):Int {
    if (count < 0) {
      throw "Quadrants scratch count must be non-negative";
    }
    return count == 0 ? 1 : count;
  }

  function closeOwnedTensors():Void {
    if (i32Tensor != null) {
      i32Tensor.close();
      i32Tensor = null;
      i32Capacity = 0;
    }
    if (f32Tensor != null) {
      f32Tensor.close();
      f32Tensor = null;
      f32Capacity = 0;
    }
  }
}
