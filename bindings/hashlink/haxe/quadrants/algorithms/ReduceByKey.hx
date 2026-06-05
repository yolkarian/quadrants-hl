package quadrants.algorithms;

import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;

class ReduceByKey {
  public static function deviceReduceByKeyAdd(keys:Tensor<I32>,
      values:Dynamic,
      outKeys:Tensor<I32>,
      outValues:Dynamic,
      countOut:Tensor<I32>,
      ?n:Int = -1):Void {
    var keysTensor = requireTensor(keys, "keys");
    var valuesTensor = requireTensor(values, "values");
    var outKeysTensor = requireTensor(outKeys, "outKeys");
    var outValuesTensor = requireTensor(outValues, "outValues");
    var countOutTensor = requireTensor(countOut, "countOut");
    requireDType(keysTensor, DType.I32, "keys");
    requireSupportedDType(valuesTensor, "values");
    requireDType(outKeysTensor, DType.I32, "outKeys");
    requireSameDType(valuesTensor, outValuesTensor, "outValues");
    requireDType(countOutTensor, DType.I32, "countOut");
    requireSameContext(keysTensor.context, valuesTensor.context, "values");
    requireSameContext(keysTensor.context, outKeysTensor.context, "outKeys");
    requireSameContext(keysTensor.context, outValuesTensor.context, "outValues");
    requireSameContext(keysTensor.context, countOutTensor.context, "countOut");
    var count = checkedInputCount(keysTensor, n);
    requireElementCountAtLeast(valuesTensor, count, "values");
    requireElementCountAtLeast(outKeysTensor, count, "outKeys");
    requireElementCountAtLeast(outValuesTensor, count, "outValues");
    requireElementCountAtLeast(countOutTensor, 1, "countOut");
    switch (valuesTensor.dtype) {
      case DType.I32:
        reduceByKeyAddI32(keys, cast values, outKeys, cast outValues, countOut, count);
      case DType.F32:
        reduceByKeyAddF32(keys, cast values, outKeys, cast outValues, countOut, count);
      default:
        throw "Quadrants reduce-by-key supports only I32 and F32 value tensors";
    }
  }

  static function reduceByKeyAddI32(keys:Tensor<I32>, values:Tensor<I32>, outKeys:Tensor<I32>, outValues:Tensor<I32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<I32>, outKeys:Tensor<I32>, outValues:Tensor<I32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc = 0;
            for (j in 0...n) {
              if (keys[j] == key) {
                acc += values[j];
              }
            }
            outKeys[outCount] = key;
            outValues[outCount] = acc;
            outCount += 1;
          }
        }
        countOut[0] = outCount;
      });
      kernel.launch(keys, values, outKeys, outValues, countOut, n);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function reduceByKeyAddF32(keys:Tensor<I32>, values:Tensor<F32>, outKeys:Tensor<I32>, outValues:Tensor<F32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<F32>, outKeys:Tensor<I32>, outValues:Tensor<F32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc:F32 = 0.0;
            for (j in 0...n) {
              if (keys[j] == key) {
                acc += values[j];
              }
            }
            outKeys[outCount] = key;
            outValues[outCount] = acc;
            outCount += 1;
          }
        }
        countOut[0] = outCount;
      });
      kernel.launch(keys, values, outKeys, outValues, countOut, n);
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
      throw 'Quadrants ${name} dtype must match values dtype';
    }
  }

  static function requireSameContext(expected:Context, actual:Context, name:String):Void {
    if (actual != expected) {
      throw 'Quadrants ${name} context must match keys context';
    }
  }

  static function requireElementCountAtLeast(tensor:TensorRuntime, count:Int, name:String):Void {
    if (tensor.elementCount() < count) {
      throw 'Quadrants ${name} tensor is too small';
    }
  }

  static function checkedInputCount(keys:TensorRuntime, n:Int):Int {
    var total = keys.elementCount();
    var count = n < 0 ? total : n;
    if (count < 0 || count > total) {
      throw "Quadrants reduce-by-key count is out of range";
    }
    return count;
  }

  static function closeKernel(kernel:Kernel):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
