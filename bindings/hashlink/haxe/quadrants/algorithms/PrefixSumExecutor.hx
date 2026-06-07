package quadrants.algorithms;

import quadrants.Context;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

class PrefixSumExecutor {
  public final context:Context;
  final scratch:Scratch;
  final ownsScratch:Bool;
  var closed:Bool = false;

  public function new(context:Context, ?scratch:Scratch) {
    if (context == null) {
      throw "Quadrants PrefixSumExecutor context is required";
    }
    if (scratch != null && scratch.context != context) {
      throw "Quadrants PrefixSumExecutor scratch context must match executor context";
    }
    this.context = context;
    ownsScratch = scratch == null;
    this.scratch = ownsScratch ? new Scratch(context) : scratch;
  }

  public function deviceExclusiveScanAdd<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    requireOpen();
    Scan.deviceExclusiveScanAdd(input, output, n);
  }

  public function deviceExclusiveScanMin<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    requireOpen();
    Scan.deviceExclusiveScanMin(input, output, n);
  }

  public function deviceExclusiveScanMax<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    requireOpen();
    Scan.deviceExclusiveScanMax(input, output, n);
  }

  public function i32Scratch(count:Int):Tensor<I32> {
    requireOpen();
    return scratch.i32(count);
  }

  public function u32Scratch(count:Int):Tensor<U32> {
    requireOpen();
    return scratch.u32(count);
  }

  public function i64Scratch(count:Int):Tensor<I64> {
    requireOpen();
    return scratch.i64(count);
  }

  public function u64Scratch(count:Int):Tensor<U64> {
    requireOpen();
    return scratch.u64(count);
  }

  public function f32Scratch(count:Int):Tensor<F32> {
    requireOpen();
    return scratch.f32(count);
  }

  public function f64Scratch(count:Int):Tensor<F64> {
    requireOpen();
    return scratch.f64(count);
  }

  public function reset():Void {
    requireOpen();
    scratch.reset();
  }

  public function close():Void {
    if (!closed) {
      if (ownsScratch) {
        scratch.close();
      }
      closed = true;
    }
  }

  function requireOpen():Void {
    if (closed) {
      throw "Quadrants PrefixSumExecutor is closed";
    }
  }
}
