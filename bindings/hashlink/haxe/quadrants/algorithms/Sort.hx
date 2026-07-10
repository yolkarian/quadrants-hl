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

class Sort {
  public static function parallelSort<T>(values:Tensor<T>, ?n:Int = -1, ascending:Bool = true):Void {
    var valuesTensor:TensorRuntime = cast values;
    requireSortDType(valuesTensor, "values");
    var count = checkedInputCount(valuesTensor, n, "sort");
    switch (valuesTensor.dtype) {
      case DType.I32:
        sortI32Impl(cast values, count, ascending);
      case DType.U32:
        sortU32Impl(cast values, count, ascending);
      case DType.I64:
        sortI64Impl(cast values, count, ascending);
      case DType.U64:
        sortU64Impl(cast values, count, ascending);
      case DType.F32:
        sortF32Impl(cast values, count, ascending);
      case DType.F64:
        sortF64Impl(cast values, count, ascending);
      default:
        throw "Quadrants sort supports only I32, U32, I64, U64, F32, and F64 tensors";
    }
  }

  public static function sortI32(values:Tensor<I32>, ?n:Int = -1, ascending:Bool = true):Void {
    sortI32Impl(values, checkedInputCount(cast values, n, "sort"), ascending);
  }

  public static function sortU32(values:Tensor<U32>, ?n:Int = -1, ascending:Bool = true):Void {
    sortU32Impl(values, checkedInputCount(cast values, n, "sort"), ascending);
  }

  public static function sortI64(values:Tensor<I64>, ?n:Int = -1, ascending:Bool = true):Void {
    sortI64Impl(values, checkedInputCount(cast values, n, "sort"), ascending);
  }

  public static function sortU64(values:Tensor<U64>, ?n:Int = -1, ascending:Bool = true):Void {
    sortU64Impl(values, checkedInputCount(cast values, n, "sort"), ascending);
  }

  public static function sortF32(values:Tensor<F32>, ?n:Int = -1, ascending:Bool = true):Void {
    sortF32Impl(values, checkedInputCount(cast values, n, "sort"), ascending);
  }

  public static function sortF64(values:Tensor<F64>, ?n:Int = -1, ascending:Bool = true):Void {
    sortF64Impl(values, checkedInputCount(cast values, n, "sort"), ascending);
  }

  public static function deviceRadixSort<T>(input:Tensor<T>,
      output:Tensor<T>,
      ?n:Int = -1,
      ascending:Bool = true,
      beginBit:Int = 0,
      endBit:Int = -1):Void {
    var inputTensor:TensorRuntime = cast input;
    var outputTensor:TensorRuntime = cast output;
    requireRadixKeyDType(inputTensor, "input");
    requireSameDType(inputTensor, outputTensor, "output");
    requireSameContext(inputTensor.context, outputTensor.context, "output");
    var count = checkedInputCount(inputTensor, n, "radix sort");
    requireElementCountAtLeast(outputTensor, count, "output");
    switch (inputTensor.dtype) {
      case DType.I32:
        var end = checkedBitRange(beginBit, endBit, 32);
        radixSortI32(cast input, cast output, count, ascending, beginBit, mask32(beginBit, end));
      case DType.U32:
        var end = checkedBitRange(beginBit, endBit, 32);
        radixSortU32(cast input, cast output, count, ascending, beginBit, mask32(beginBit, end));
      case DType.I64:
        var end = checkedBitRange(beginBit, endBit, 64);
        radixSortI64(cast input, cast output, count, ascending, beginBit, mask64(beginBit, end));
      case DType.U64:
        var end = checkedBitRange(beginBit, endBit, 64);
        radixSortU64(cast input, cast output, count, ascending, beginBit, mask64(beginBit, end));
      case DType.F32:
        var end = checkedBitRange(beginBit, endBit, 32);
        radixSortF32(cast input, cast output, count, ascending, beginBit, mask32(beginBit, end));
      default:
        throw "Quadrants radix sort supports only I32, U32, I64, U64, and F32 key tensors";
    }
  }

  public static function deviceRadixSortPairs<TKey, TValue>(keysIn:Tensor<TKey>,
      valuesIn:Tensor<TValue>,
      keysOut:Tensor<TKey>,
      valuesOut:Tensor<TValue>,
      ?n:Int = -1,
      ascending:Bool = true,
      beginBit:Int = 0,
      endBit:Int = -1):Void {
    var keysInTensor:TensorRuntime = cast keysIn;
    var valuesInTensor:TensorRuntime = cast valuesIn;
    var keysOutTensor:TensorRuntime = cast keysOut;
    var valuesOutTensor:TensorRuntime = cast valuesOut;
    requireRadixKeyDType(keysInTensor, "keysIn");
    requireSortDType(valuesInTensor, "valuesIn");
    requireSameDType(keysInTensor, keysOutTensor, "keysOut");
    requireSameDType(valuesInTensor, valuesOutTensor, "valuesOut");
    requireSameContext(keysInTensor.context, valuesInTensor.context, "valuesIn");
    requireSameContext(keysInTensor.context, keysOutTensor.context, "keysOut");
    requireSameContext(keysInTensor.context, valuesOutTensor.context, "valuesOut");
    var count = checkedInputCount(keysInTensor, n, "radix sort pairs");
    requireElementCountAtLeast(valuesInTensor, count, "valuesIn");
    requireElementCountAtLeast(keysOutTensor, count, "keysOut");
    requireElementCountAtLeast(valuesOutTensor, count, "valuesOut");
    switch (keysInTensor.dtype) {
      case DType.I32:
        var end = checkedBitRange(beginBit, endBit, 32);
        switch (valuesInTensor.dtype) {
          case DType.I32:
            radixSortPairsI32I32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.U32:
            radixSortPairsI32U32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.I64:
            radixSortPairsI32I64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.U64:
            radixSortPairsI32U64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.F32:
            radixSortPairsI32F32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.F64:
            radixSortPairsI32F64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          default:
            throw "Quadrants radix sort pair values support only I32, U32, I64, U64, F32, and F64 tensors";
        }
      case DType.U32:
        var end = checkedBitRange(beginBit, endBit, 32);
        switch (valuesInTensor.dtype) {
          case DType.I32:
            radixSortPairsU32I32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.U32:
            radixSortPairsU32U32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.I64:
            radixSortPairsU32I64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.U64:
            radixSortPairsU32U64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.F32:
            radixSortPairsU32F32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          case DType.F64:
            radixSortPairsU32F64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask32(beginBit, end));
          default:
            throw "Quadrants radix sort pair values support only I32, U32, I64, U64, F32, and F64 tensors";
        }
      case DType.I64:
        var end = checkedBitRange(beginBit, endBit, 64);
        switch (valuesInTensor.dtype) {
          case DType.I32:
            radixSortPairsI64I32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.U32:
            radixSortPairsI64U32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.I64:
            radixSortPairsI64I64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.U64:
            radixSortPairsI64U64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.F32:
            radixSortPairsI64F32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.F64:
            radixSortPairsI64F64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          default:
            throw "Quadrants radix sort pair values support only I32, U32, I64, U64, F32, and F64 tensors";
        }
      case DType.U64:
        var end = checkedBitRange(beginBit, endBit, 64);
        switch (valuesInTensor.dtype) {
          case DType.I32:
            radixSortPairsU64I32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.U32:
            radixSortPairsU64U32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.I64:
            radixSortPairsU64I64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.U64:
            radixSortPairsU64U64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.F32:
            radixSortPairsU64F32(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          case DType.F64:
            radixSortPairsU64F64(cast keysIn, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, mask64(beginBit, end));
          default:
            throw "Quadrants radix sort pair values support only I32, U32, I64, U64, F32, and F64 tensors";
        }
      case DType.F32:
        var end = checkedBitRange(beginBit, endBit, 32);
        var rangeMask = mask32(beginBit, end);
        encodeF32SortableBits(cast keysIn, cast keysOut, count);
        switch (valuesInTensor.dtype) {
          case DType.I32:
            radixSortPairsF32I32(cast keysOut, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, rangeMask);
          case DType.U32:
            radixSortPairsF32U32(cast keysOut, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, rangeMask);
          case DType.I64:
            radixSortPairsF32I64(cast keysOut, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, rangeMask);
          case DType.U64:
            radixSortPairsF32U64(cast keysOut, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, rangeMask);
          case DType.F32:
            radixSortPairsF32F32(cast keysOut, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, rangeMask);
          case DType.F64:
            radixSortPairsF32F64(cast keysOut, cast valuesIn, cast keysOut, cast valuesOut, count, ascending, beginBit, rangeMask);
          default:
            throw "Quadrants radix sort pair values support only I32, U32, I64, U64, F32, and F64 tensors";
        }
        decodeF32SortableBits(cast keysOut, cast keysOut, count);
      default:
        throw "Quadrants radix sort pairs supports only I32, U32, I64, U64, and F32 key tensors";
    }
  }

  static function sortI32Impl(values:Tensor<I32>, n:Int, ascending:Bool):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<I32>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) best = j;
            } else {
              if (values[j] > values[best]) best = j;
            }
            j += 1;
          }
          if (best != i) {
            var tmp:I32 = values[i];
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

  static function sortU32Impl(values:Tensor<U32>, n:Int, ascending:Bool):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<U32>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) best = j;
            } else {
              if (values[j] > values[best]) best = j;
            }
            j += 1;
          }
          if (best != i) {
            var tmp:U32 = values[i];
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

  static function sortI64Impl(values:Tensor<I64>, n:Int, ascending:Bool):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<I64>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) best = j;
            } else {
              if (values[j] > values[best]) best = j;
            }
            j += 1;
          }
          if (best != i) {
            var tmp:I64 = values[i];
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

  static function sortU64Impl(values:Tensor<U64>, n:Int, ascending:Bool):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<U64>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) best = j;
            } else {
              if (values[j] > values[best]) best = j;
            }
            j += 1;
          }
          if (best != i) {
            var tmp:U64 = values[i];
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

  static function sortF32Impl(values:Tensor<F32>, n:Int, ascending:Bool):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<F32>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) best = j;
            } else {
              if (values[j] > values[best]) best = j;
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

  static function sortF64Impl(values:Tensor<F64>, n:Int, ascending:Bool):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(values.context, macro (values:Tensor<F64>, n:Int, ascending:Bool) -> {
        var i = 0;
        while (i < n) {
          var best = i;
          var j = i + 1;
          while (j < n) {
            if (ascending) {
              if (values[j] < values[best]) best = j;
            } else {
              if (values[j] > values[best]) best = j;
            }
            j += 1;
          }
          if (best != i) {
            var tmp:F64 = values[i];
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

  static function radixSortI32(input:Tensor<I32>, output:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) output[i] = input[i];
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = output[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = output[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              output[j] = previousKey;
              j -= 1;
            } else {
              break;
            }
          }
          output[j] = key;
          i += 1;
        }
      });
      kernel.launch(input, output, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortU32(input:Tensor<U32>, output:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U32>, output:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) output[i] = input[i];
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = output[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = output[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              output[j] = previousKey;
              j -= 1;
            } else {
              break;
            }
          }
          output[j] = key;
          i += 1;
        }
      });
      kernel.launch(input, output, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortF32(input:Tensor<F32>, output:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    encodeF32SortableBits(input, output, n);
    radixSortF32SortableBits(output, output, n, ascending, beginBit, mask);
    decodeF32SortableBits(output, output, n);
  }

  static function encodeF32SortableBits(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
      var signMask:U32 = -2147483647 - 1;
      var allBits:U32 = -1;
      for (i in 0...n) {
        var bits:U32 = bitCast(input[i], U32);
        // Positive bit patterns XOR the sign bit; negative ones XOR every bit.
        var twiddle:U32 = signMask;
        if ((bits & signMask) != 0) {
          twiddle = allBits;
        }
        output[i] = bitCast(bits ^ twiddle, F32);
      }
    });
    try {
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortF32SortableBits(input:Tensor<F32>, output:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) output[i] = input[i];
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        // Keys are sortable U32 bit patterns stored in F32 slots; never compare them as floats.
        var key:F32 = output[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = output[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            output[j] = previousKey;
            j -= 1;
          } else {
            break;
          }
        }
        output[j] = key;
        i += 1;
      }
    });
    try {
      kernel.launch(input, output, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function decodeF32SortableBits(input:Tensor<F32>, output:Tensor<F32>, n:Int):Void {
    var kernel = Kernel.build(input.context, macro (input:Tensor<F32>, output:Tensor<F32>, n:Int) -> {
      var signMask:U32 = -2147483647 - 1;
      var allBits:U32 = -1;
      for (i in 0...n) {
        var sortableBits:U32 = bitCast(input[i], U32);
        // The inverse branches on the sortable output sign bit, not the original sign bit.
        var twiddle:U32 = allBits;
        if ((sortableBits & signMask) != 0) {
          twiddle = signMask;
        }
        output[i] = bitCast(sortableBits ^ twiddle, F32);
      }
    });
    try {
      kernel.launch(input, output, n);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortI64(input:Tensor<I64>, output:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<I64>, output:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) output[i] = input[i];
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = output[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = output[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              output[j] = previousKey;
              j -= 1;
            } else {
              break;
            }
          }
          output[j] = key;
          i += 1;
        }
      });
      kernel.launch(input, output, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortU64(input:Tensor<U64>, output:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(input.context, macro (input:Tensor<U64>, output:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) output[i] = input[i];
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = output[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = output[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              output[j] = previousKey;
              j -= 1;
            } else {
              break;
            }
          }
          output[j] = key;
          i += 1;
        }
      });
      kernel.launch(input, output, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }


  static function radixSortPairsI32I32(keysIn:Tensor<I32>, valuesIn:Tensor<I32>, keysOut:Tensor<I32>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I32>, valuesIn:Tensor<I32>, keysOut:Tensor<I32>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = keysOut[i];
          var value:I32 = valuesOut[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = keysOut[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI32U32(keysIn:Tensor<I32>, valuesIn:Tensor<U32>, keysOut:Tensor<I32>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I32>, valuesIn:Tensor<U32>, keysOut:Tensor<I32>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = keysOut[i];
          var value:U32 = valuesOut[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = keysOut[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI32I64(keysIn:Tensor<I32>, valuesIn:Tensor<I64>, keysOut:Tensor<I32>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I32>, valuesIn:Tensor<I64>, keysOut:Tensor<I32>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = keysOut[i];
          var value:I64 = valuesOut[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = keysOut[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI32U64(keysIn:Tensor<I32>, valuesIn:Tensor<U64>, keysOut:Tensor<I32>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I32>, valuesIn:Tensor<U64>, keysOut:Tensor<I32>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = keysOut[i];
          var value:U64 = valuesOut[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = keysOut[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI32F32(keysIn:Tensor<I32>, valuesIn:Tensor<F32>, keysOut:Tensor<I32>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I32>, valuesIn:Tensor<F32>, keysOut:Tensor<I32>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = keysOut[i];
          var value:F32 = valuesOut[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = keysOut[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI32F64(keysIn:Tensor<I32>, valuesIn:Tensor<F64>, keysOut:Tensor<I32>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I32>, valuesIn:Tensor<F64>, keysOut:Tensor<I32>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var signMask:I32 = -2147483647 - 1;
        var i = 1;
        while (i < n) {
          var key:I32 = keysOut[i];
          var value:F64 = valuesOut[i];
          var keyBits:U32 = key ^ signMask;
          var rank:U32 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I32 = keysOut[j - 1];
            var previousBits:U32 = previousKey ^ signMask;
            var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU32I32(keysIn:Tensor<U32>, valuesIn:Tensor<I32>, keysOut:Tensor<U32>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U32>, valuesIn:Tensor<I32>, keysOut:Tensor<U32>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = keysOut[i];
          var value:I32 = valuesOut[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = keysOut[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU32U32(keysIn:Tensor<U32>, valuesIn:Tensor<U32>, keysOut:Tensor<U32>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U32>, valuesIn:Tensor<U32>, keysOut:Tensor<U32>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = keysOut[i];
          var value:U32 = valuesOut[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = keysOut[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU32I64(keysIn:Tensor<U32>, valuesIn:Tensor<I64>, keysOut:Tensor<U32>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U32>, valuesIn:Tensor<I64>, keysOut:Tensor<U32>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = keysOut[i];
          var value:I64 = valuesOut[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = keysOut[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU32U64(keysIn:Tensor<U32>, valuesIn:Tensor<U64>, keysOut:Tensor<U32>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U32>, valuesIn:Tensor<U64>, keysOut:Tensor<U32>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = keysOut[i];
          var value:U64 = valuesOut[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = keysOut[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU32F32(keysIn:Tensor<U32>, valuesIn:Tensor<F32>, keysOut:Tensor<U32>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U32>, valuesIn:Tensor<F32>, keysOut:Tensor<U32>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = keysOut[i];
          var value:F32 = valuesOut[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = keysOut[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU32F64(keysIn:Tensor<U32>, valuesIn:Tensor<F64>, keysOut:Tensor<U32>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U32>, valuesIn:Tensor<F64>, keysOut:Tensor<U32>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U32 = mask;
        var i = 1;
        while (i < n) {
          var key:U32 = keysOut[i];
          var value:F64 = valuesOut[i];
          var rank:U32 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U32 = keysOut[j - 1];
            var previousRank:U32 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI64I32(keysIn:Tensor<I64>, valuesIn:Tensor<I32>, keysOut:Tensor<I64>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I64>, valuesIn:Tensor<I32>, keysOut:Tensor<I64>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = keysOut[i];
          var value:I32 = valuesOut[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = keysOut[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI64U32(keysIn:Tensor<I64>, valuesIn:Tensor<U32>, keysOut:Tensor<I64>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I64>, valuesIn:Tensor<U32>, keysOut:Tensor<I64>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = keysOut[i];
          var value:U32 = valuesOut[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = keysOut[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI64I64(keysIn:Tensor<I64>, valuesIn:Tensor<I64>, keysOut:Tensor<I64>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I64>, valuesIn:Tensor<I64>, keysOut:Tensor<I64>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = keysOut[i];
          var value:I64 = valuesOut[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = keysOut[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI64U64(keysIn:Tensor<I64>, valuesIn:Tensor<U64>, keysOut:Tensor<I64>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I64>, valuesIn:Tensor<U64>, keysOut:Tensor<I64>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = keysOut[i];
          var value:U64 = valuesOut[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = keysOut[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI64F32(keysIn:Tensor<I64>, valuesIn:Tensor<F32>, keysOut:Tensor<I64>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I64>, valuesIn:Tensor<F32>, keysOut:Tensor<I64>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = keysOut[i];
          var value:F32 = valuesOut[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = keysOut[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsI64F64(keysIn:Tensor<I64>, valuesIn:Tensor<F64>, keysOut:Tensor<I64>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<I64>, valuesIn:Tensor<F64>, keysOut:Tensor<I64>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64, signMask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var sign:U64 = signMask;
        var i = 1;
        while (i < n) {
          var key:I64 = keysOut[i];
          var value:F64 = valuesOut[i];
          var keyBits:U64 = key ^ sign;
          var rank:U64 = (keyBits >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:I64 = keysOut[j - 1];
            var previousBits:U64 = previousKey ^ sign;
            var previousRank:U64 = (previousBits >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask, i64Min());
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU64I32(keysIn:Tensor<U64>, valuesIn:Tensor<I32>, keysOut:Tensor<U64>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U64>, valuesIn:Tensor<I32>, keysOut:Tensor<U64>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = keysOut[i];
          var value:I32 = valuesOut[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = keysOut[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU64U32(keysIn:Tensor<U64>, valuesIn:Tensor<U32>, keysOut:Tensor<U64>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U64>, valuesIn:Tensor<U32>, keysOut:Tensor<U64>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = keysOut[i];
          var value:U32 = valuesOut[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = keysOut[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU64I64(keysIn:Tensor<U64>, valuesIn:Tensor<I64>, keysOut:Tensor<U64>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U64>, valuesIn:Tensor<I64>, keysOut:Tensor<U64>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = keysOut[i];
          var value:I64 = valuesOut[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = keysOut[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU64U64(keysIn:Tensor<U64>, valuesIn:Tensor<U64>, keysOut:Tensor<U64>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U64>, valuesIn:Tensor<U64>, keysOut:Tensor<U64>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = keysOut[i];
          var value:U64 = valuesOut[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = keysOut[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU64F32(keysIn:Tensor<U64>, valuesIn:Tensor<F32>, keysOut:Tensor<U64>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U64>, valuesIn:Tensor<F32>, keysOut:Tensor<U64>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = keysOut[i];
          var value:F32 = valuesOut[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = keysOut[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  static function radixSortPairsU64F64(keysIn:Tensor<U64>, valuesIn:Tensor<F64>, keysOut:Tensor<U64>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64):Void {
    var kernel:Dynamic = null;
    try {
      kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<U64>, valuesIn:Tensor<F64>, keysOut:Tensor<U64>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:haxe.Int64) -> {
        for (i in 0...n) {
          keysOut[i] = keysIn[i];
          valuesOut[i] = valuesIn[i];
        }
        var rangeMask:U64 = mask;
        var i = 1;
        while (i < n) {
          var key:U64 = keysOut[i];
          var value:F64 = valuesOut[i];
          var rank:U64 = (key >> beginBit) & rangeMask;
          var j = i;
          while (j > 0) {
            var previousKey:U64 = keysOut[j - 1];
            var previousRank:U64 = (previousKey >> beginBit) & rangeMask;
            var move:Bool = false;
            if (ascending) {
              if (rank < previousRank) move = true;
            } else {
              if (rank > previousRank) move = true;
            }
            if (move) {
              keysOut[j] = previousKey;
              valuesOut[j] = valuesOut[j - 1];
              j -= 1;
            } else {
              break;
            }
          }
          keysOut[j] = key;
          valuesOut[j] = value;
          i += 1;
        }
      });
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      closeKernel(kernel);
      throw e;
    }
  }

  // F32 key slots hold sortable U32 bit patterns until decodeF32SortableBits restores them.
  static function radixSortPairsF32I32(keysIn:Tensor<F32>, valuesIn:Tensor<I32>, keysOut:Tensor<F32>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<F32>, valuesIn:Tensor<I32>, keysOut:Tensor<F32>, valuesOut:Tensor<I32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) {
        keysOut[i] = keysIn[i];
        valuesOut[i] = valuesIn[i];
      }
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        var key:F32 = keysOut[i];
        var value:I32 = valuesOut[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = keysOut[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            keysOut[j] = previousKey;
            valuesOut[j] = valuesOut[j - 1];
            j -= 1;
          } else {
            break;
          }
        }
        keysOut[j] = key;
        valuesOut[j] = value;
        i += 1;
      }
    });
    try {
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortPairsF32U32(keysIn:Tensor<F32>, valuesIn:Tensor<U32>, keysOut:Tensor<F32>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<F32>, valuesIn:Tensor<U32>, keysOut:Tensor<F32>, valuesOut:Tensor<U32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) {
        keysOut[i] = keysIn[i];
        valuesOut[i] = valuesIn[i];
      }
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        var key:F32 = keysOut[i];
        var value:U32 = valuesOut[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = keysOut[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            keysOut[j] = previousKey;
            valuesOut[j] = valuesOut[j - 1];
            j -= 1;
          } else {
            break;
          }
        }
        keysOut[j] = key;
        valuesOut[j] = value;
        i += 1;
      }
    });
    try {
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortPairsF32I64(keysIn:Tensor<F32>, valuesIn:Tensor<I64>, keysOut:Tensor<F32>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<F32>, valuesIn:Tensor<I64>, keysOut:Tensor<F32>, valuesOut:Tensor<I64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) {
        keysOut[i] = keysIn[i];
        valuesOut[i] = valuesIn[i];
      }
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        var key:F32 = keysOut[i];
        var value:I64 = valuesOut[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = keysOut[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            keysOut[j] = previousKey;
            valuesOut[j] = valuesOut[j - 1];
            j -= 1;
          } else {
            break;
          }
        }
        keysOut[j] = key;
        valuesOut[j] = value;
        i += 1;
      }
    });
    try {
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortPairsF32U64(keysIn:Tensor<F32>, valuesIn:Tensor<U64>, keysOut:Tensor<F32>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<F32>, valuesIn:Tensor<U64>, keysOut:Tensor<F32>, valuesOut:Tensor<U64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) {
        keysOut[i] = keysIn[i];
        valuesOut[i] = valuesIn[i];
      }
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        var key:F32 = keysOut[i];
        var value:U64 = valuesOut[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = keysOut[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            keysOut[j] = previousKey;
            valuesOut[j] = valuesOut[j - 1];
            j -= 1;
          } else {
            break;
          }
        }
        keysOut[j] = key;
        valuesOut[j] = value;
        i += 1;
      }
    });
    try {
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortPairsF32F32(keysIn:Tensor<F32>, valuesIn:Tensor<F32>, keysOut:Tensor<F32>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<F32>, valuesIn:Tensor<F32>, keysOut:Tensor<F32>, valuesOut:Tensor<F32>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) {
        keysOut[i] = keysIn[i];
        valuesOut[i] = valuesIn[i];
      }
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        var key:F32 = keysOut[i];
        var value:F32 = valuesOut[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = keysOut[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            keysOut[j] = previousKey;
            valuesOut[j] = valuesOut[j - 1];
            j -= 1;
          } else {
            break;
          }
        }
        keysOut[j] = key;
        valuesOut[j] = value;
        i += 1;
      }
    });
    try {
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function radixSortPairsF32F64(keysIn:Tensor<F32>, valuesIn:Tensor<F64>, keysOut:Tensor<F32>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:Int):Void {
    var kernel = Kernel.build(keysIn.context, macro (keysIn:Tensor<F32>, valuesIn:Tensor<F64>, keysOut:Tensor<F32>, valuesOut:Tensor<F64>, n:Int, ascending:Bool, beginBit:Int, mask:Int) -> {
      for (i in 0...n) {
        keysOut[i] = keysIn[i];
        valuesOut[i] = valuesIn[i];
      }
      var rangeMask:U32 = mask;
      var i = 1;
      while (i < n) {
        var key:F32 = keysOut[i];
        var value:F64 = valuesOut[i];
        var keyBits:U32 = bitCast(key, U32);
        var rank:U32 = (keyBits >> beginBit) & rangeMask;
        var j = i;
        while (j > 0) {
          var previousKey:F32 = keysOut[j - 1];
          var previousBits:U32 = bitCast(previousKey, U32);
          var previousRank:U32 = (previousBits >> beginBit) & rangeMask;
          var move:Bool = false;
          if (ascending) {
            if (rank < previousRank) move = true;
          } else {
            if (rank > previousRank) move = true;
          }
          if (move) {
            keysOut[j] = previousKey;
            valuesOut[j] = valuesOut[j - 1];
            j -= 1;
          } else {
            break;
          }
        }
        keysOut[j] = key;
        valuesOut[j] = value;
        i += 1;
      }
    });
    try {
      kernel.launch(keysIn, valuesIn, keysOut, valuesOut, n, ascending, beginBit, mask);
      kernel.close();
    } catch (e:Dynamic) {
      kernel.close();
      throw e;
    }
  }

  static function requireSortDType(tensor:TensorRuntime, name:String):Void {
    switch (tensor.dtype) {
      case DType.I32 | DType.U32 | DType.I64 | DType.U64 | DType.F32 | DType.F64:
      default:
        throw 'Quadrants ${name} must be an I32, U32, I64, U64, F32, or F64 Tensor';
    }
  }

  static function requireRadixKeyDType(tensor:TensorRuntime, name:String):Void {
    switch (tensor.dtype) {
      case DType.I32 | DType.U32 | DType.I64 | DType.U64 | DType.F32:
      default:
        throw 'Quadrants ${name} must be an I32, U32, I64, U64, or F32 Tensor';
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

  static function checkedInputCount(input:TensorRuntime, n:Int, operation:String):Int {
    var total = input.elementCount();
    var count = n < 0 ? total : n;
    if (count < 0 || count > total) {
      throw 'Quadrants ${operation} count is out of range';
    }
    return count;
  }

  static function checkedBitRange(beginBit:Int, endBit:Int, totalBits:Int):Int {
    var end = endBit < 0 ? totalBits : endBit;
    if (beginBit < 0 || end < beginBit || end > totalBits) {
      throw 'Quadrants radix sort bit range must satisfy 0 <= beginBit <= endBit <= ${totalBits}';
    }
    return end;
  }

  static function mask32(beginBit:Int, endBit:Int):Int {
    var width = endBit - beginBit;
    if (width == 0) return 0;
    if (width >= 32) return -1;
    return (1 << width) - 1;
  }

  static function mask64(beginBit:Int, endBit:Int):haxe.Int64 {
    var width = endBit - beginBit;
    if (width == 0) return haxe.Int64.make(0, 0);
    if (width >= 64) return haxe.Int64.make(-1, -1);
    var mask = haxe.Int64.make(0, 0);
    for (_ in 0...width) {
      mask = (mask << 1) | haxe.Int64.make(0, 1);
    }
    return mask;
  }

  static inline function i64Min():haxe.Int64 {
    return haxe.Int64.make(-2147483648, 0);
  }

  static function closeKernel(kernel:Dynamic):Void {
    if (kernel != null) {
      kernel.close();
    }
  }
}
