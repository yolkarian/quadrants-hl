package quadrants.algorithms;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U8;
import quadrants.Types.U32;
import quadrants.Types.U64;

class Scratch {
  public final context:Context;
  var u8Tensor:Tensor<U8> = null;
  var i32Tensor:Tensor<I32> = null;
  var u32Tensor:Tensor<U32> = null;
  var i64Tensor:Tensor<I64> = null;
  var u64Tensor:Tensor<U64> = null;
  var f32Tensor:Tensor<F32> = null;
  var f64Tensor:Tensor<F64> = null;
  var u8Capacity:Int = 0;
  var i32Capacity:Int = 0;
  var u32Capacity:Int = 0;
  var i64Capacity:Int = 0;
  var u64Capacity:Int = 0;
  var f32Capacity:Int = 0;
  var f64Capacity:Int = 0;
  var closed:Bool = false;

  public function new(context:Context) {
    if (context == null) {
      throw "Quadrants scratch context is required";
    }
    this.context = context;
  }

  public static function create(context:Context):Scratch {
    return new Scratch(context);
  }

  public function reserve(bytes:Int):Void {
    requireOpen();
    var capacity = requestedCapacity(bytes);
    if (u8Tensor == null || u8Capacity < capacity) {
      if (u8Tensor != null) {
        u8Tensor.close();
      }
      u8Tensor = new Tensor<U8>(context, [capacity]);
      u8Capacity = capacity;
    }
  }

  public function clear():Void {
    reset();
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

  public function u32(count:Int):Tensor<U32> {
    requireOpen();
    var capacity = requestedCapacity(count);
    if (u32Tensor == null || u32Capacity < capacity) {
      if (u32Tensor != null) {
        u32Tensor.close();
      }
      u32Tensor = new Tensor<U32>(context, [capacity]);
      u32Capacity = capacity;
    }
    return u32Tensor;
  }

  public function i64(count:Int):Tensor<I64> {
    requireOpen();
    var capacity = requestedCapacity(count);
    if (i64Tensor == null || i64Capacity < capacity) {
      if (i64Tensor != null) {
        i64Tensor.close();
      }
      i64Tensor = new Tensor<I64>(context, [capacity]);
      i64Capacity = capacity;
    }
    return i64Tensor;
  }

  public function u64(count:Int):Tensor<U64> {
    requireOpen();
    var capacity = requestedCapacity(count);
    if (u64Tensor == null || u64Capacity < capacity) {
      if (u64Tensor != null) {
        u64Tensor.close();
      }
      u64Tensor = new Tensor<U64>(context, [capacity]);
      u64Capacity = capacity;
    }
    return u64Tensor;
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

  public function f64(count:Int):Tensor<F64> {
    requireOpen();
    var capacity = requestedCapacity(count);
    if (f64Tensor == null || f64Capacity < capacity) {
      if (f64Tensor != null) {
        f64Tensor.close();
      }
      f64Tensor = new Tensor<F64>(context, [capacity]);
      f64Capacity = capacity;
    }
    return f64Tensor;
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
    if (u8Tensor != null) {
      u8Tensor.close();
      u8Tensor = null;
      u8Capacity = 0;
    }
    if (i32Tensor != null) {
      i32Tensor.close();
      i32Tensor = null;
      i32Capacity = 0;
    }
    if (u32Tensor != null) {
      u32Tensor.close();
      u32Tensor = null;
      u32Capacity = 0;
    }
    if (i64Tensor != null) {
      i64Tensor.close();
      i64Tensor = null;
      i64Capacity = 0;
    }
    if (u64Tensor != null) {
      u64Tensor.close();
      u64Tensor = null;
      u64Capacity = 0;
    }
    if (f32Tensor != null) {
      f32Tensor.close();
      f32Tensor = null;
      f32Capacity = 0;
    }
    if (f64Tensor != null) {
      f64Tensor.close();
      f64Tensor = null;
      f64Capacity = 0;
    }
  }
}
