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

class Select {
  public static function deviceSelect<T>(input:Tensor<T>,
      flags:Tensor<I32>,
      output:Tensor<T>,
      countOut:Tensor<I32>,
      ?n:Int = -1):Void {
    var inputTensor:TensorRuntime = cast input;
    var flagsTensor:TensorRuntime = cast flags;
    var outputTensor:TensorRuntime = cast output;
    var countOutTensor:TensorRuntime = cast countOut;
    requireSupportedDType(inputTensor, "input");
    requireDType(flagsTensor, DType.I32, "flags");
    requireSameDType(inputTensor, outputTensor, "output");
    requireDType(countOutTensor, DType.I32, "countOut");
    requireSameContext(inputTensor.context, flagsTensor.context, "flags");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    requireSameContext(inputTensor.context, countOutTensor.context, "countOut");
    var count = checkedInputCount(inputTensor, n);
    requireElementCountAtLeast(flagsTensor, count, "flags");
    requireElementCountAtLeast(outputTensor, count, "output");
    requireElementCountAtLeast(countOutTensor, 1, "countOut");
    switch (inputTensor.dtype) {
      case DType.I32:
        selectI32(cast input, flags, cast output, countOut, count);
      case DType.U32:
        selectU32(cast input, flags, cast output, countOut, count);
      case DType.I64:
        selectI64(cast input, flags, cast output, countOut, count);
      case DType.U64:
        selectU64(cast input, flags, cast output, countOut, count);
      case DType.F32:
        selectF32(cast input, flags, cast output, countOut, count);
      case DType.F64:
        selectF64(cast input, flags, cast output, countOut, count);
      default:
        throw "Quadrants select supports only I32, U32, I64, U64, F32, and F64 tensors";
    }
  }

  public static function selectI32(input:Tensor<I32>, flags:Tensor<I32>, output:Tensor<I32>, countOut:Tensor<I32>, ?n:Int = -1):Void {
    selectI32Impl(input, flags, output, countOut, checkedArgs(input, flags, output, countOut, n));
  }

  public static function selectU32(input:Tensor<U32>, flags:Tensor<I32>, output:Tensor<U32>, countOut:Tensor<I32>, ?n:Int = -1):Void {
    selectU32Impl(input, flags, output, countOut, checkedArgs(input, flags, output, countOut, n));
  }

  public static function selectI64(input:Tensor<I64>, flags:Tensor<I32>, output:Tensor<I64>, countOut:Tensor<I32>, ?n:Int = -1):Void {
    selectI64Impl(input, flags, output, countOut, checkedArgs(input, flags, output, countOut, n));
  }

  public static function selectU64(input:Tensor<U64>, flags:Tensor<I32>, output:Tensor<U64>, countOut:Tensor<I32>, ?n:Int = -1):Void {
    selectU64Impl(input, flags, output, countOut, checkedArgs(input, flags, output, countOut, n));
  }

  public static function selectF32(input:Tensor<F32>, flags:Tensor<I32>, output:Tensor<F32>, countOut:Tensor<I32>, ?n:Int = -1):Void {
    selectF32Impl(input, flags, output, countOut, checkedArgs(input, flags, output, countOut, n));
  }

  public static function selectF64(input:Tensor<F64>, flags:Tensor<I32>, output:Tensor<F64>, countOut:Tensor<I32>, ?n:Int = -1):Void {
    selectF64Impl(input, flags, output, countOut, checkedArgs(input, flags, output, countOut, n));
  }

  static function selectI32Impl(input:Tensor<I32>, flags:Tensor<I32>, output:Tensor<I32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, flags:Tensor<I32>, output:Tensor<I32>, countOut:Tensor<I32>, n:Int) -> {
        var count = 0;
        for (i in 0...n) {
          if (flags[i] != 0) {
            output[count] = input[i];
            count += 1;
          }
        }
        countOut[0] = count;
      });
      kernel.launch(input, flags, output, countOut, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function selectU32Impl(input:Tensor<U32>, flags:Tensor<I32>, output:Tensor<U32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, flags:Tensor<I32>, output:Tensor<U32>, countOut:Tensor<I32>, n:Int) -> {
        var count = 0;
        for (i in 0...n) {
          if (flags[i] != 0) {
            output[count] = input[i];
            count += 1;
          }
        }
        countOut[0] = count;
      });
      kernel.launch(input, flags, output, countOut, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function selectI64Impl(input:Tensor<I64>, flags:Tensor<I32>, output:Tensor<I64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, flags:Tensor<I32>, output:Tensor<I64>, countOut:Tensor<I32>, n:Int) -> {
        var count = 0;
        for (i in 0...n) {
          if (flags[i] != 0) {
            output[count] = input[i];
            count += 1;
          }
        }
        countOut[0] = count;
      });
      kernel.launch(input, flags, output, countOut, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function selectU64Impl(input:Tensor<U64>, flags:Tensor<I32>, output:Tensor<U64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, flags:Tensor<I32>, output:Tensor<U64>, countOut:Tensor<I32>, n:Int) -> {
        var count = 0;
        for (i in 0...n) {
          if (flags[i] != 0) {
            output[count] = input[i];
            count += 1;
          }
        }
        countOut[0] = count;
      });
      kernel.launch(input, flags, output, countOut, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function selectF32Impl(input:Tensor<F32>, flags:Tensor<I32>, output:Tensor<F32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F32>, flags:Tensor<I32>, output:Tensor<F32>, countOut:Tensor<I32>, n:Int) -> {
        var count = 0;
        for (i in 0...n) {
          if (flags[i] != 0) {
            output[count] = input[i];
            count += 1;
          }
        }
        countOut[0] = count;
      });
      kernel.launch(input, flags, output, countOut, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function selectF64Impl(input:Tensor<F64>, flags:Tensor<I32>, output:Tensor<F64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<F64>, flags:Tensor<I32>, output:Tensor<F64>, countOut:Tensor<I32>, n:Int) -> {
        var count = 0;
        for (i in 0...n) {
          if (flags[i] != 0) {
            output[count] = input[i];
            count += 1;
          }
        }
        countOut[0] = count;
      });
      kernel.launch(input, flags, output, countOut, n);
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

  static function requireDType(tensor:TensorRuntime, dtype:DType, name:String):Void {
    if (tensor.dtype != dtype) {
      throw 'Quadrants ${name} dtype mismatch';
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
      throw "Quadrants select count is out of range";
    }
    return count;
  }

  static function checkedArgs<T>(input:Tensor<T>, flags:Tensor<I32>, output:Tensor<T>, countOut:Tensor<I32>, n:Int):Int {
    var inputTensor:TensorRuntime = cast input;
    var flagsTensor:TensorRuntime = cast flags;
    var outputTensor:TensorRuntime = cast output;
    var countOutTensor:TensorRuntime = cast countOut;
    requireDType(flagsTensor, DType.I32, "flags");
    requireSameDType(inputTensor, outputTensor, "output");
    requireDType(countOutTensor, DType.I32, "countOut");
    requireSameContext(inputTensor.context, flagsTensor.context, "flags");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    requireSameContext(inputTensor.context, countOutTensor.context, "countOut");
    var count = checkedInputCount(inputTensor, n);
    requireElementCountAtLeast(flagsTensor, count, "flags");
    requireElementCountAtLeast(outputTensor, count, "output");
    requireElementCountAtLeast(countOutTensor, 1, "countOut");
    return count;
  }

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
