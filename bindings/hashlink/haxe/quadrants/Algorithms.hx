package quadrants;

import quadrants.algorithms.Reduce;
import quadrants.algorithms.ReduceByKey;
import quadrants.algorithms.Scan;
import quadrants.algorithms.Select;
import quadrants.algorithms.Sort;
import quadrants.algorithms.Scratch;
import quadrants.Types.I32;

typedef RadixSortOptions = {
  @:optional var beginBit:Int;
  @:optional var endBit:Int;
  @:optional var ascending:Bool;
}

class Algorithms {
  public static function reduceAdd<T>(ctx:Context, input:Tensor<T>, output:Tensor<T>, ?scratch:Scratch, ?n:Int = -1):Void {
    requireContext(ctx, input);
    Reduce.deviceReduceAdd(input, output, n);
  }

  public static function reduceMin<T>(ctx:Context, input:Tensor<T>, output:Tensor<T>, ?scratch:Scratch, ?n:Int = -1):Void {
    requireContext(ctx, input);
    Reduce.deviceReduceMin(input, output, n);
  }

  public static function exclusiveScanAdd<T>(ctx:Context, input:Tensor<T>, output:Tensor<T>, ?scratch:Scratch, ?n:Int = -1):Void {
    requireContext(ctx, input);
    Scan.deviceExclusiveScanAdd(input, output, n);
  }

  public static function select<T>(ctx:Context, input:Tensor<T>, flags:Tensor<I32>, output:Tensor<T>, count:Tensor<I32>, ?scratch:Scratch, ?n:Int = -1):Void {
    requireContext(ctx, input);
    Select.deviceSelect(input, flags, output, count, n);
  }

  public static function radixSort<T>(ctx:Context, keys:Tensor<T>, tmpKeys:Tensor<T>, ?scratch:Scratch, ?options:RadixSortOptions):Void {
    requireContext(ctx, keys);
    Sort.deviceRadixSort(keys, tmpKeys, -1,
      options == null || options.ascending != false,
      options == null || options.beginBit == null ? 0 : options.beginBit,
      options == null || options.endBit == null ? -1 : options.endBit);
  }

  public static function radixSortPairs<TKey, TValue>(ctx:Context,
      keys:Tensor<TKey>,
      tmpKeys:Tensor<TKey>,
      values:Tensor<TValue>,
      tmpValues:Tensor<TValue>,
      ?scratch:Scratch,
      ?options:RadixSortOptions):Void {
    requireContext(ctx, keys);
    Sort.deviceRadixSortPairs(keys, values, tmpKeys, tmpValues, -1,
      options == null || options.ascending != false,
      options == null || options.beginBit == null ? 0 : options.beginBit,
      options == null || options.endBit == null ? -1 : options.endBit);
  }

  public static function reduceByKeyAdd<T>(ctx:Context,
      keys:Tensor<I32>,
      values:Tensor<T>,
      outKeys:Tensor<I32>,
      outValues:Tensor<T>,
      count:Tensor<I32>,
      ?scratch:Scratch,
      ?n:Int = -1):Void {
    requireContext(ctx, keys);
    ReduceByKey.deviceReduceByKeyAdd(keys, values, outKeys, outValues, count, n);
  }

  static function requireContext(ctx:Context, tensor:Dynamic):Void {
    if (ctx == null) {
      throw "Quadrants Algorithms require a Context";
    }
    var runtime:TensorRuntime = cast tensor;
    if (runtime.context != ctx) {
      throw "Quadrants Algorithms tensor belongs to a different Context";
    }
  }
}
