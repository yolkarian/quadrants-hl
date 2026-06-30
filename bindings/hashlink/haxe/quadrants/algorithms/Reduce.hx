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

class Reduce {
  public static function deviceReduceAdd<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireSupportedDType(inputTensor, "input");
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    requireElementCountAtLeast(outputTensor, 1, "output");
    var count = checkedInputCount(inputTensor, n);
    switch (inputTensor.dtype) {
      case DType.I32:
        reduceAddI32(cast input, cast output, count);
      case DType.U32:
        reduceAddU32(cast input, cast output, count);
      case DType.I64:
        reduceAddI64(cast input, cast output, count);
      case DType.U64:
        reduceAddU64(cast input, cast output, count);
      case DType.F32:
        reduceAddF32(cast input, cast output, count);
      case DType.F64:
        reduceAddF64(cast input, cast output, count);
      default:
        throw "Quadrants reduce supports only I32, U32, I64, U64, F32, and F64 tensors";
    }
  }

  public static function deviceReduceMin<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireSupportedDType(inputTensor, "input");
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    requireElementCountAtLeast(outputTensor, 1, "output");
    var count = checkedInputCount(inputTensor, n);
    requireNonEmpty(count, "min");
    switch (inputTensor.dtype) {
      case DType.I32:
        reduceMinI32(cast input, cast output, count);
      case DType.U32:
        reduceMinU32(cast input, cast output, count);
      case DType.I64:
        reduceMinI64(cast input, cast output, count);
      case DType.U64:
        reduceMinU64(cast input, cast output, count);
      case DType.F32:
        reduceMinF32(cast input, cast output, count);
      case DType.F64:
        reduceMinF64(cast input, cast output, count);
      default:
        throw "Quadrants reduce supports only I32, U32, I64, U64, F32, and F64 tensors";
    }
  }

  public static function deviceReduceMax<T>(input:Tensor<T>, output:Tensor<T>, ?n:Int = -1):Void {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireSupportedDType(inputTensor, "input");
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    requireElementCountAtLeast(outputTensor, 1, "output");
    var count = checkedInputCount(inputTensor, n);
    requireNonEmpty(count, "max");
    switch (inputTensor.dtype) {
      case DType.I32:
        reduceMaxI32(cast input, cast output, count);
      case DType.U32:
        reduceMaxU32(cast input, cast output, count);
      case DType.I64:
        reduceMaxI64(cast input, cast output, count);
      case DType.U64:
        reduceMaxU64(cast input, cast output, count);
      case DType.F32:
        reduceMaxF32(cast input, cast output, count);
      case DType.F64:
        reduceMaxF64(cast input, cast output, count);
      default:
        throw "Quadrants reduce supports only I32, U32, I64, U64, F32, and F64 tensors";
    }
  }

  public static function addI32(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1):Void {
    reduceAddI32(input, output, checkedArgs(input, output, n));
  }

  public static function addU32(input:Tensor<U32>, output:Tensor<U32>, ?n:Int = -1):Void {
    reduceAddU32(input, output, checkedArgs(input, output, n));
  }

  public static function addI64(input:Tensor<I64>, output:Tensor<I64>, ?n:Int = -1):Void {
    reduceAddI64(input, output, checkedArgs(input, output, n));
  }

  public static function addU64(input:Tensor<U64>, output:Tensor<U64>, ?n:Int = -1):Void {
    reduceAddU64(input, output, checkedArgs(input, output, n));
  }

  public static function addF32(input:Tensor<F32>, output:Tensor<F32>, ?n:Int = -1):Void {
    reduceAddF32(input, output, checkedArgs(input, output, n));
  }

  public static function addF64(input:Tensor<F64>, output:Tensor<F64>, ?n:Int = -1):Void {
    reduceAddF64(input, output, checkedArgs(input, output, n));
  }

  public static function minI32(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "min");
    reduceMinI32(input, output, count);
  }

  public static function minU32(input:Tensor<U32>, output:Tensor<U32>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "min");
    reduceMinU32(input, output, count);
  }

  public static function minI64(input:Tensor<I64>, output:Tensor<I64>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "min");
    reduceMinI64(input, output, count);
  }

  public static function minU64(input:Tensor<U64>, output:Tensor<U64>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "min");
    reduceMinU64(input, output, count);
  }

  public static function minF32(input:Tensor<F32>, output:Tensor<F32>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "min");
    reduceMinF32(input, output, count);
  }

  public static function minF64(input:Tensor<F64>, output:Tensor<F64>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "min");
    reduceMinF64(input, output, count);
  }

  public static function maxI32(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "max");
    reduceMaxI32(input, output, count);
  }

  public static function maxU32(input:Tensor<U32>, output:Tensor<U32>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "max");
    reduceMaxU32(input, output, count);
  }

  public static function maxI64(input:Tensor<I64>, output:Tensor<I64>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "max");
    reduceMaxI64(input, output, count);
  }

  public static function maxU64(input:Tensor<U64>, output:Tensor<U64>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "max");
    reduceMaxU64(input, output, count);
  }

  public static function maxF32(input:Tensor<F32>, output:Tensor<F32>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "max");
    reduceMaxF32(input, output, count);
  }

  public static function maxF64(input:Tensor<F64>, output:Tensor<F64>, ?n:Int = -1):Void {
    var count = checkedArgs(input, output, n);
    requireNonEmpty(count, "max");
    reduceMaxF64(input, output, count);
  }

  static function reduceAddI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc:I32 = 0;
        for (i in 0...n) {
          acc += input[i];
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceAddU32(input:Tensor<U32>, output:Tensor<U32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int) -> {
        var acc:U32 = 0;
        for (i in 0...n) {
          acc += input[i];
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceAddI64(input:Tensor<I64>, output:Tensor<I64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int) -> {
        var acc:I64 = 0;
        for (i in 0...n) {
          acc += input[i];
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceAddU64(input:Tensor<U64>, output:Tensor<U64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int) -> {
        var acc:U64 = 0;
        for (i in 0...n) {
          acc += input[i];
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceAddF32(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
        var acc:F32 = 0.0;
        for (i in 0...n) {
          acc += input[i];
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceAddF64(input:Tensor<F64>, output:Tensor<F64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, output:Tensor<F64>, n:Int) -> {
        var acc:F64 = 0.0;
        for (i in 0...n) {
          acc += input[i];
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMinI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc:I32 = input[0];
        for (i in 1...n) {
          if (input[i] < acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMinU32(input:Tensor<U32>, output:Tensor<U32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int) -> {
        var acc:U32 = input[0];
        for (i in 1...n) {
          if (input[i] < acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMinI64(input:Tensor<I64>, output:Tensor<I64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int) -> {
        var acc:I64 = input[0];
        for (i in 1...n) {
          if (input[i] < acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMinU64(input:Tensor<U64>, output:Tensor<U64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int) -> {
        var acc:U64 = input[0];
        for (i in 1...n) {
          if (input[i] < acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMinF32(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
        var acc:F32 = input[0];
        for (i in 1...n) {
          if (input[i] < acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMinF64(input:Tensor<F64>, output:Tensor<F64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, output:Tensor<F64>, n:Int) -> {
        var acc:F64 = input[0];
        for (i in 1...n) {
          if (input[i] < acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMaxI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc:I32 = input[0];
        for (i in 1...n) {
          if (input[i] > acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMaxU32(input:Tensor<U32>, output:Tensor<U32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int) -> {
        var acc:U32 = input[0];
        for (i in 1...n) {
          if (input[i] > acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMaxI64(input:Tensor<I64>, output:Tensor<I64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int) -> {
        var acc:I64 = input[0];
        for (i in 1...n) {
          if (input[i] > acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMaxU64(input:Tensor<U64>, output:Tensor<U64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int) -> {
        var acc:U64 = input[0];
        for (i in 1...n) {
          if (input[i] > acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMaxF32(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
        var acc:F32 = input[0];
        for (i in 1...n) {
          if (input[i] > acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
      });
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceMaxF64(input:Tensor<F64>, output:Tensor<F64>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, output:Tensor<F64>, n:Int) -> {
        var acc:F64 = input[0];
        for (i in 1...n) {
          if (input[i] > acc) {
            acc = input[i];
          }
        }
        output[0] = acc;
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
      throw "Quadrants reduce count is out of range";
    }
    return count;
  }

  static function checkedArgs<T>(input:Tensor<T>, output:Tensor<T>, n:Int):Int {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    requireElementCountAtLeast(outputTensor, 1, "output");
    return checkedInputCount(inputTensor, n);
  }

  static function requireNonEmpty(count:Int, operation:String):Void {
    if (count == 0) {
      throw 'Quadrants reduce ${operation} requires at least one input element';
    }
  }

  static function closeKernel(kernel:Dynamic):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
