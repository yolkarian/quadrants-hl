package quadrants.algorithms;

import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

class Sort {
  public static function parallelSort<T>(values:Tensor<T>, ?n:Int = -1, ascending:Bool = true):Void {
    var valuesTensor:TensorRuntime = cast values;
    requireSupportedDType(valuesTensor, "values");
    var count = checkedInputCount(valuesTensor, n, "sort");
    switch (valuesTensor.dtype) {
      case DType.I32:
        sortI32(cast values, count, ascending);
      case DType.F32:
        sortF32(cast values, count, ascending);
      default:
        throw "Quadrants sort supports only I32 and F32 tensors";
    }
  }

  public static function deviceRadixSort(input:Tensor<I32>, output:Tensor<I32>, ?n:Int = -1, ascending:Bool = true):Void {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireDType(inputTensor, DType.I32, "input");
    requireDType(outputTensor, DType.I32, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    var count = checkedInputCount(inputTensor, n, "radix sort");
    requireElementCountAtLeast(outputTensor, count, "output");
    radixSortI32(input, output, count, ascending);
  }

  static function sortI32(values:Tensor<I32>, n:Int, ascending:Bool):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<I32>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) {
                best = j;
              }
            } else {
              if (values[j] > values[best]) {
                best = j;
              }
            }
            j += 1;
          }
          if (best != i) {
            var tmp = values[i];
            values[i] = values[best];
            values[best] = tmp;
          }
          i += 1;
        }
      });
      kernel.launch(values, n, ascending);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function sortF32(values:Tensor<F32>, n:Int, ascending:Bool):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<F32>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) {
                best = j;
              }
            } else {
              if (values[j] > values[best]) {
                best = j;
              }
            }
            j += 1;
          }
          if (best != i) {
            var tmp:F32 = values[i];
            values[i] = values[best];
            values[best] = tmp;
          }
          i += 1;
        }
      });
      kernel.launch(values, n, ascending);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortI32(input:Tensor<I32>, output:Tensor<I32>, n:Int, ascending:Bool):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int, ascending:Bool) -> {
        for (i in 0...n) {
          output[i] = input[i];
        }
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (output[j] < output[best]) {
                best = j;
              }
            } else {
              if (output[j] > output[best]) {
                best = j;
              }
            }
            j += 1;
          }
          if (best != i) {
            var tmp = output[i];
            output[i] = output[best];
            output[best] = tmp;
          }
          i += 1;
        }
      });
      kernel.launch(input, output, n, ascending);
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

  static function requireDType(tensor:TensorRuntime, dtype:DType, name:String):Void {
    if (tensor.dtype != dtype) {
      throw 'Quadrants ${name} dtype mismatch';
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

  static function checkedInputCount(input:TensorRuntime, n:Int, operation:String):Int {
    var total = input.elementCount();
    var count = n < 0 ? total : n;
    if (count < 0 || count > total) {
      throw 'Quadrants ${operation} count is out of range';
    }
    return count;
  }

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
