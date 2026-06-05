package quadrants.algorithms;

import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

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
      case DType.F32:
        switch (op) {
          case "add": scanAddF32(cast input, cast output, count);
          case "min": scanMinF32(cast input, cast output, count);
          case "max": scanMaxF32(cast input, cast output, count);
          default: throw "Quadrants scan operation is unsupported";
        }
      default:
        throw "Quadrants scan supports only I32 and F32 tensors";
    }
  }

  static function scanAddI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc = 0;
        for (i in 0...n) {
          var current = input[i];
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

  static function scanMinI32(input:Tensor<I32>, output:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
        var acc = 2147483647;
        for (i in 0...n) {
          var current = input[i];
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
        var acc = -2147483647 - 1;
        for (i in 0...n) {
          var current = input[i];
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
      throw "Quadrants scan count is out of range";
    }
    return count;
  }

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
