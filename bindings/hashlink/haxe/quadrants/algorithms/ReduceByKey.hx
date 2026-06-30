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

class ReduceByKey {
  public static function deviceReduceByKeyAdd<T>(keys:Tensor<I32>,
      values:Tensor<T>,
      outKeys:Tensor<I32>,
      outValues:Tensor<T>,
      countOut:Tensor<I32>,
      ?n:Int = -1):Void {
    dispatch(keys, values, outKeys, outValues, countOut, n, false);
  }

  public static function reduceByKeyGlobalAdd<T>(keys:Tensor<I32>,
      values:Tensor<T>,
      outKeys:Tensor<I32>,
      outValues:Tensor<T>,
      countOut:Tensor<I32>,
      ?n:Int = -1):Void {
    dispatch(keys, values, outKeys, outValues, countOut, n, true);
  }

  public static function deviceReduceByKeyGlobalAdd<T>(keys:Tensor<I32>,
      values:Tensor<T>,
      outKeys:Tensor<I32>,
      outValues:Tensor<T>,
      countOut:Tensor<I32>,
      ?n:Int = -1):Void {
    reduceByKeyGlobalAdd(keys, values, outKeys, outValues, countOut, n);
  }

  static function dispatch<T>(keys:Tensor<I32>,
      values:Tensor<T>,
      outKeys:Tensor<I32>,
      outValues:Tensor<T>,
      countOut:Tensor<I32>,
      n:Int,
      global:Bool):Void {
    var keysTensor:TensorRuntime = cast keys;
    var valuesTensor:TensorRuntime = cast values;
    var outKeysTensor:TensorRuntime = cast outKeys;
    var outValuesTensor:TensorRuntime = cast outValues;
    var countOutTensor:TensorRuntime = cast countOut;
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
        if (global) reduceByKeyGlobalAddI32(keys, cast values, outKeys, cast outValues, countOut, count) else reduceByKeyAddI32(keys, cast values, outKeys, cast outValues, countOut, count);
      case DType.U32:
        if (global) reduceByKeyGlobalAddU32(keys, cast values, outKeys, cast outValues, countOut, count) else reduceByKeyAddU32(keys, cast values, outKeys, cast outValues, countOut, count);
      case DType.I64:
        if (global) reduceByKeyGlobalAddI64(keys, cast values, outKeys, cast outValues, countOut, count) else reduceByKeyAddI64(keys, cast values, outKeys, cast outValues, countOut, count);
      case DType.U64:
        if (global) reduceByKeyGlobalAddU64(keys, cast values, outKeys, cast outValues, countOut, count) else reduceByKeyAddU64(keys, cast values, outKeys, cast outValues, countOut, count);
      case DType.F32:
        if (global) reduceByKeyGlobalAddF32(keys, cast values, outKeys, cast outValues, countOut, count) else reduceByKeyAddF32(keys, cast values, outKeys, cast outValues, countOut, count);
      case DType.F64:
        if (global) reduceByKeyGlobalAddF64(keys, cast values, outKeys, cast outValues, countOut, count) else reduceByKeyAddF64(keys, cast values, outKeys, cast outValues, countOut, count);
      default:
        throw "Quadrants reduce-by-key supports only I32, U32, I64, U64, F32, and F64 value tensors";
    }
  }

  static function reduceByKeyAddI32(keys:Tensor<I32>, values:Tensor<I32>, outKeys:Tensor<I32>, outValues:Tensor<I32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<I32>, outKeys:Tensor<I32>, outValues:Tensor<I32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        if (n > 0) {
          var currentKey:I32 = keys[0];
          var acc:I32 = values[0];
          for (i in 1...n) {
            if (keys[i] == currentKey) {
              acc += values[i];
            } else {
              outKeys[outCount] = currentKey;
              outValues[outCount] = acc;
              outCount += 1;
              currentKey = keys[i];
              acc = values[i];
            }
          }
          outKeys[outCount] = currentKey;
          outValues[outCount] = acc;
          outCount += 1;
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

  static function reduceByKeyAddU32(keys:Tensor<I32>, values:Tensor<U32>, outKeys:Tensor<I32>, outValues:Tensor<U32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<U32>, outKeys:Tensor<I32>, outValues:Tensor<U32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        if (n > 0) {
          var currentKey:I32 = keys[0];
          var acc:U32 = values[0];
          for (i in 1...n) {
            if (keys[i] == currentKey) {
              acc += values[i];
            } else {
              outKeys[outCount] = currentKey;
              outValues[outCount] = acc;
              outCount += 1;
              currentKey = keys[i];
              acc = values[i];
            }
          }
          outKeys[outCount] = currentKey;
          outValues[outCount] = acc;
          outCount += 1;
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

  static function reduceByKeyAddI64(keys:Tensor<I32>, values:Tensor<I64>, outKeys:Tensor<I32>, outValues:Tensor<I64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<I64>, outKeys:Tensor<I32>, outValues:Tensor<I64>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        if (n > 0) {
          var currentKey:I32 = keys[0];
          var acc:I64 = values[0];
          for (i in 1...n) {
            if (keys[i] == currentKey) {
              acc += values[i];
            } else {
              outKeys[outCount] = currentKey;
              outValues[outCount] = acc;
              outCount += 1;
              currentKey = keys[i];
              acc = values[i];
            }
          }
          outKeys[outCount] = currentKey;
          outValues[outCount] = acc;
          outCount += 1;
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

  static function reduceByKeyAddU64(keys:Tensor<I32>, values:Tensor<U64>, outKeys:Tensor<I32>, outValues:Tensor<U64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<U64>, outKeys:Tensor<I32>, outValues:Tensor<U64>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        if (n > 0) {
          var currentKey:I32 = keys[0];
          var acc:U64 = values[0];
          for (i in 1...n) {
            if (keys[i] == currentKey) {
              acc += values[i];
            } else {
              outKeys[outCount] = currentKey;
              outValues[outCount] = acc;
              outCount += 1;
              currentKey = keys[i];
              acc = values[i];
            }
          }
          outKeys[outCount] = currentKey;
          outValues[outCount] = acc;
          outCount += 1;
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
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<F32>, outKeys:Tensor<I32>, outValues:Tensor<F32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        if (n > 0) {
          var currentKey:I32 = keys[0];
          var acc:F32 = values[0];
          for (i in 1...n) {
            if (keys[i] == currentKey) {
              acc += values[i];
            } else {
              outKeys[outCount] = currentKey;
              outValues[outCount] = acc;
              outCount += 1;
              currentKey = keys[i];
              acc = values[i];
            }
          }
          outKeys[outCount] = currentKey;
          outValues[outCount] = acc;
          outCount += 1;
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

  static function reduceByKeyAddF64(keys:Tensor<I32>, values:Tensor<F64>, outKeys:Tensor<I32>, outValues:Tensor<F64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<F64>, outKeys:Tensor<I32>, outValues:Tensor<F64>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        if (n > 0) {
          var currentKey:I32 = keys[0];
          var acc:F64 = values[0];
          for (i in 1...n) {
            if (keys[i] == currentKey) {
              acc += values[i];
            } else {
              outKeys[outCount] = currentKey;
              outValues[outCount] = acc;
              outCount += 1;
              currentKey = keys[i];
              acc = values[i];
            }
          }
          outKeys[outCount] = currentKey;
          outValues[outCount] = acc;
          outCount += 1;
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

  static function reduceByKeyGlobalAddI32(keys:Tensor<I32>, values:Tensor<I32>, outKeys:Tensor<I32>, outValues:Tensor<I32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<I32>, outKeys:Tensor<I32>, outValues:Tensor<I32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key:I32 = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc:I32 = 0;
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

  static function reduceByKeyGlobalAddU32(keys:Tensor<I32>, values:Tensor<U32>, outKeys:Tensor<I32>, outValues:Tensor<U32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<U32>, outKeys:Tensor<I32>, outValues:Tensor<U32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key:I32 = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc:U32 = 0;
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

  static function reduceByKeyGlobalAddI64(keys:Tensor<I32>, values:Tensor<I64>, outKeys:Tensor<I32>, outValues:Tensor<I64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<I64>, outKeys:Tensor<I32>, outValues:Tensor<I64>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key:I32 = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc:I64 = 0;
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

  static function reduceByKeyGlobalAddU64(keys:Tensor<I32>, values:Tensor<U64>, outKeys:Tensor<I32>, outValues:Tensor<U64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<U64>, outKeys:Tensor<I32>, outValues:Tensor<U64>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key:I32 = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc:U64 = 0;
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

  static function reduceByKeyGlobalAddF32(keys:Tensor<I32>, values:Tensor<F32>, outKeys:Tensor<I32>, outValues:Tensor<F32>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<F32>, outKeys:Tensor<I32>, outValues:Tensor<F32>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key:I32 = keys[i];
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

  static function reduceByKeyGlobalAddF64(keys:Tensor<I32>, values:Tensor<F64>, outKeys:Tensor<I32>, outValues:Tensor<F64>, countOut:Tensor<I32>, n:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keys.context, macro (keys:Tensor<I32>, values:Tensor<F64>, outKeys:Tensor<I32>, outValues:Tensor<F64>, countOut:Tensor<I32>, n:Int) -> {
        var outCount = 0;
        for (i in 0...n) {
          var key:I32 = keys[i];
          var seen = 0;
          for (j in 0...i) {
            if (keys[j] == key) {
              seen = 1;
            }
          }
          if (seen == 0) {
            var acc:F64 = 0.0;
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

  static function closeKernel(kernel:Dynamic):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
