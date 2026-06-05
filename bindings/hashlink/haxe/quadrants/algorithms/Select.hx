package quadrants.algorithms;

import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

class Select {
  public static function deviceSelect(input:Dynamic,
      flags:Tensor<I32>,
      output:Dynamic,
      countOut:Tensor<I32>,
      ?n:Int = -1):Void {
    var inputTensor = requireTensor(input, "input");
    var flagsTensor = requireTensor(flags, "flags");
    var outputTensor = requireTensor(output, "output");
    var countOutTensor = requireTensor(countOut, "countOut");
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
      case DType.F32:
        selectF32(cast input, flags, cast output, countOut, count);
      default:
        throw "Quadrants select supports only I32 and F32 tensors";
    }
  }

  static function selectI32(input:Tensor<I32>, flags:Tensor<I32>, output:Tensor<I32>, countOut:Tensor<I32>, n:Int):Void {
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

  static function selectF32(input:Tensor<F32>, flags:Tensor<I32>, output:Tensor<F32>, countOut:Tensor<I32>, n:Int):Void {
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

  static function requireTensor(value:Dynamic, name:String):TensorRuntime {
    if (!Std.isOfType(value, TensorRuntime)) {
      throw 'Quadrants ${name} must be a Tensor';
    }
    return cast value;
  }

  static function requireSupportedDType(tensor:TensorRuntime, name:String):Void {
    switch (tensor.dtype) {
      case DType.I32 | DType.F32:
      default:
        throw 'Quadrants ${name} must be an I32 or F32 Tensor';
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

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
