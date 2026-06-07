package quadrants.algorithms;

import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

class Scan {
  public static function deviceExclusiveScanAdd<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    dispatch(input, output, n, "add");
  }

  public static function deviceExclusiveScanMin<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    dispatch(input, output, n, "min");
  }

  public static function deviceExclusiveScanMax<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    dispatch(input, output, n, "max");
  }

  public static function exclusiveAddI32(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1):Void {
    scanAddI32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveAddU32(input:Tensor<U32>, output:Tensor<U32>, ?n:Int = -1):Void {
    scanAddU32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveAddI64(input:Tensor<I64>, output:Tensor<I64>, ?n:Int = -1):Void {
    scanAddI64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveAddU64(input:Tensor<U64>, output:Tensor<U64>, ?n:Int = -1):Void {
    scanAddU64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveAddF32(input:Tensor<F32>, output:Tensor<F32>, ?n:Int = -1):Void {
    scanAddF32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveAddF64(input:Tensor<F64>, output:Tensor<F64>, ?n:Int = -1):Void {
    scanAddF64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMinI32(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1):Void {
    scanMinI32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMinU32(input:Tensor<U32>, output:Tensor<U32>, ?n:Int = -1):Void {
    scanMinU32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMinI64(input:Tensor<I64>, output:Tensor<I64>, ?n:Int = -1):Void {
    scanMinI64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMinU64(input:Tensor<U64>, output:Tensor<U64>, ?n:Int = -1):Void {
    scanMinU64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMinF32(input:Tensor<F32>, output:Tensor<F32>, ?n:Int = -1):Void {
    scanMinF32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMinF64(input:Tensor<F64>, output:Tensor<F64>, ?n:Int = -1):Void {
    scanMinF64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMaxI32(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1):Void {
    scanMaxI32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMaxU32(input:Tensor<U32>, output:Tensor<U32>, ?n:Int = -1):Void {
    scanMaxU32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMaxI64(input:Tensor<I64>, output:Tensor<I64>, ?n:Int = -1):Void {
    scanMaxI64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMaxU64(input:Tensor<U64>, output:Tensor<U64>, ?n:Int = -1):Void {
    scanMaxU64(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMaxF32(input:Tensor<F32>, output:Tensor<F32>, ?n:Int = -1):Void {
    scanMaxF32(input, output, checkedArgs(input, output, n));
  }

  public static function exclusiveMaxF64(input:Tensor<F64>, output:Tensor<F64>, ?n:Int = -1):Void {
    scanMaxF64(input, output, checkedArgs(input, output, n));
  }

  static function dispatch<T>(input:Tensor<T>, output:Tensor<T>, n:Int, op:String):Void {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireSupportedDType(inputTensor, "input");
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    var count = checkedInputCount(inputTensor, n);
    requireElementCountAtLeast(outputTensor, count, "output");
    switch (inputTensor.dtype) {
      case DType.I32:
        switch (op) {
          case "add": scanAddI32(cast input, cast output, count);
          case "min": scanMinI32(cast input, cast output, count);
          case "max": scanMaxI32(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      case DType.U32:
        switch (op) {
          case "add": scanAddU32(cast input, cast output, count);
          case "min": scanMinU32(cast input, cast output, count);
          case "max": scanMaxU32(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      case DType.I64:
        switch (op) {
          case "add": scanAddI64(cast input, cast output, count);
          case "min": scanMinI64(cast input, cast output, count);
          case "max": scanMaxI64(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      case DType.U64:
        switch (op) {
          case "add": scanAddU64(cast input, cast output, count);
          case "min": scanMinU64(cast input, cast output, count);
          case "max": scanMaxU64(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      case DType.F32:
        switch (op) {
          case "add": scanAddF32(cast input, cast output, count);
          case "min": scanMinF32(cast input, cast output, count);
          case "max": scanMaxF32(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      case DType.F64:
        switch (op) {
          case "add": scanAddF64(cast input, cast output, count);
          case "min": scanMinF64(cast input, cast output, count);
          case "max": scanMaxF64(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      default:
        throw "Quadrants scan supports only I32, U32, I64, U64, F32, and F64 tensors";
    }
  }

  static function scanAddI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc:I32 = 0;
        for (i in 0...n) {
          var current:I32 = input[i];
          output[i] = acc;
          acc += current;
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanAddU32(input:Tensor<U32>, output:Tensor<U32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int) -> {
        var acc:U32 = 0;
        for (i in 0...n) {
          var current:U32 = input[i];
          output[i] = acc;
          acc += current;
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanAddI64(input:Tensor<I64>, output:Tensor<I64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int) -> {
        var acc:I64 = 0;
        for (i in 0...n) {
          var current:I64 = input[i];
          output[i] = acc;
          acc += current;
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanAddU64(input:Tensor<U64>, output:Tensor<U64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int) -> {
        var acc:U64 = 0;
        for (i in 0...n) {
          var current:U64 = input[i];
          output[i] = acc;
          acc += current;
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanAddF32(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
        var acc:F32 = 0.0;
        for (i in 0...n) {
          var current:F32 = input[i];
          output[i] = acc;
          acc += current;
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanAddF64(input:Tensor<F64>, output:Tensor<F64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, output:Tensor<F64>, n:Int) -> {
        var acc:F64 = 0.0;
        for (i in 0...n) {
          var current:F64 = input[i];
          output[i] = acc;
          acc += current;
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMinI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc:I32 = 2147483647;
        for (i in 0...n) {
          var current:I32 = input[i];
          output[i] = acc;
          if (current < acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMinU32(input:Tensor<U32>, output:Tensor<U32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int, identity:U32) -> {
        var acc:U32 = identity;
        for (i in 0...n) {
          var current:U32 = input[i];
          output[i] = acc;
          if (current < acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n, u32Max());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMinI64(input:Tensor<I64>, output:Tensor<I64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int, identity:haxe.Int64) -> {
        var acc:I64 = identity;
        for (i in 0...n) {
          var current:I64 = input[i];
          output[i] = acc;
          if (current < acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n, i64Max());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMinU64(input:Tensor<U64>, output:Tensor<U64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int, identity:U64) -> {
        var acc:U64 = identity;
        for (i in 0...n) {
          var current:U64 = input[i];
          output[i] = acc;
          if (current < acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n, u64Max());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMinF32(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
        var acc:F32 = 3.4028234663852886e38;
        for (i in 0...n) {
          var current:F32 = input[i];
          output[i] = acc;
          if (current < acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMinF64(input:Tensor<F64>, output:Tensor<F64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, output:Tensor<F64>, n:Int) -> {
        var acc:F64 = 1.7976931348623157e308;
        for (i in 0...n) {
          var current:F64 = input[i];
          output[i] = acc;
          if (current < acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMaxI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc:I32 = -2147483647 - 1;
        for (i in 0...n) {
          var current:I32 = input[i];
          output[i] = acc;
          if (current > acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMaxU32(input:Tensor<U32>, output:Tensor<U32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int) -> {
        var acc:U32 = 0;
        for (i in 0...n) {
          var current:U32 = input[i];
          output[i] = acc;
          if (current > acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMaxI64(input:Tensor<I64>, output:Tensor<I64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int, identity:haxe.Int64) -> {
        var acc:I64 = identity;
        for (i in 0...n) {
          var current:I64 = input[i];
          output[i] = acc;
          if (current > acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMaxU64(input:Tensor<U64>, output:Tensor<U64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int) -> {
        var acc:U64 = 0;
        for (i in 0...n) {
          var current:U64 = input[i];
          output[i] = acc;
          if (current > acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMaxF32(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
        var acc:F32 = -3.4028234663852886e38;
        for (i in 0...n) {
          var current:F32 = input[i];
          output[i] = acc;
          if (current > acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function scanMaxF64(input:Tensor<F64>, output:Tensor<F64>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, output:Tensor<F64>, n:Int) -> {
        var acc:F64 = -1.7976931348623157e308;
        for (i in 0...n) {
          var current:F64 = input[i];
          output[i] = acc;
          if (current > acc) {
            acc = current;
          }
        }
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function requireSupportedDType(tensor:TensorRuntime, name:String):Void {
    switch (tensor.dtype) {
      case DType.I32 | DType.U32 | DType.I64 | DType.U64 | DType.F32 | DType.F64:
      default:
        throw 'Quadrants ${name} must be an I32, U32, I64, U64, F32, or F64 Tensor';
    }
  }

  static function requireSameDType(expected:TensorRuntime, actual:TensorRuntime, name:String):Void {
    if (actual.dtype != expected.dtype) {
      throw 'Quadrants ${name} dtype must match input dtype';
    }
  }

  static function requireSameContext(expected:Context, actual:Context, name:String):Void {
    if (actual != expected) {
      throw 'Quadrants ${name} context must match input context';
    }
  }

  static function requireElementCountAtLeast(tensor:TensorRuntime, count:Int, name:String):Void {
    if (tensor.elementCount() < count) {
      throw 'Quadrants ${name} tensor is too small';
    }
  }

  static function checkedInputCount(input:TensorRuntime, n:Int):Int {
    var total = input.elementCount();
    var count = n < 0 ? total : n;
    if (count < 0 || count > total) {
      throw "Quadrants scan count is out of range";
    }
    return count;
  }

  static function checkedArgs<T>(input:Tensor<T>, output:Tensor<T>, n:Int):Int {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    var count = checkedInputCount(inputTensor, n);
    requireElementCountAtLeast(outputTensor, count, "output");
    return count;
  }

  static inline function u32Max():haxe.Int64 {
    return haxe.Int64.make(0, -1);
  }

  static inline function u64Max():haxe.Int64 {
    return haxe.Int64.make(-1, -1);
  }

  static inline function i64Max():haxe.Int64 {
    return haxe.Int64.make(2147483647, -1);
  }

  static inline function i64Min():haxe.Int64 {
    return haxe.Int64.make(-2147483648, 0);
  }

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
