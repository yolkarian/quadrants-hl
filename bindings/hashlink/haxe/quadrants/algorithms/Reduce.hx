package quadrants.algorithms;

import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

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
      case DType.F32:
        reduceAddF32(cast input, cast output, count);
      default:
        throw "Quadrants reduce supports only I32 and F32 tensors";
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
    if (count == 0) {
      throw "Quadrants reduce min requires at least one input element";
    }
    switch (inputTensor.dtype) {
      case DType.I32:
        reduceMinI32(cast input, cast output, count);
      case DType.F32:
        reduceMinF32(cast input, cast output, count);
      default:
        throw "Quadrants reduce supports only I32 and F32 tensors";
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
    if (count == 0) {
      throw "Quadrants reduce max requires at least one input element";
    }
    switch (inputTensor.dtype) {
      case DType.I32:
        reduceMaxI32(cast input, cast output, count);
      case DType.F32:
        reduceMaxF32(cast input, cast output, count);
      default:
        throw "Quadrants reduce supports only I32 and F32 tensors";
    }
  }

  static function reduceAddI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc = 0;
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
    var kernel:Kernel = null;
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

  static function reduceMinI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc = input[0];
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
    var kernel:Kernel = null;
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

  static function reduceMaxI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc = input[0];
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
    var kernel:Kernel = null;
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


  static function requireSupportedDType(tensor:TensorRuntime, name:String):Void {
    switch (tensor.dtype) {
      case DType.I32 | DType.F32:
      default:
        throw 'Quadrants ${name} must be an I32 or F32 Tensor';
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

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
