import haxe.Int64;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;
import quadrants.algorithms.Reduce;
import quadrants.algorithms.ReduceByKey;
import quadrants.algorithms.PrefixSumExecutor;
import quadrants.algorithms.Scan;
import quadrants.algorithms.Scratch;
import quadrants.algorithms.Select;
import quadrants.algorithms.Sort;

class TestAlgorithmsRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectInt64(name:String, got:Int64, expected:Int64):Void {
    if (Int64.compare(got, expected) != 0) {
      throw '${name}: ${Std.string(got)} != ${Std.string(expected)}';
    }
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function expectArrayI32(name:String, tensor:Tensor<I32>, expected:Array<Int>):Void {
    for (i in 0...expected.length) {
      expectEq('${name}_${i}', tensor.read(i), expected[i]);
    }
  }

  static function expectArrayU32(name:String, tensor:Tensor<U32>, expected:Array<Int64>):Void {
    for (i in 0...expected.length) {
      expectInt64('${name}_${i}', tensor.read(i), expected[i]);
    }
  }

  static function expectArrayI64(name:String, tensor:Tensor<I64>, expected:Array<Int64>):Void {
    for (i in 0...expected.length) {
      expectInt64('${name}_${i}', tensor.read(i), expected[i]);
    }
  }

  static function expectArrayU64(name:String, tensor:Tensor<U64>, expected:Array<Int64>):Void {
    for (i in 0...expected.length) {
      expectInt64('${name}_${i}', tensor.read(i), expected[i]);
    }
  }

  static function expectArrayF32(name:String, tensor:Tensor<F32>, expected:Array<Float>):Void {
    for (i in 0...expected.length) {
      expectNear('${name}_${i}', tensor.read(i), expected[i]);
    }
  }

  static function expectArrayF64(name:String, tensor:Tensor<F64>, expected:Array<Float>):Void {
    for (i in 0...expected.length) {
      expectNear('${name}_${i}', tensor.read(i), expected[i]);
    }
  }

  static function closeTensor<T>(tensor:Tensor<T>):Void {
    if (tensor != null) tensor.close();
  }

  static inline function i64(value:Int):Int64 {
    return Int64.make(value < 0 ? -1 : 0, value);
  }

  static inline function i64Max():Int64 {
    return Int64.make(2147483647, -1);
  }

  static inline function i64Min():Int64 {
    return Int64.make(-2147483648, 0);
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(name, ctx) {
      if (name != "cpu") {
        Sys.println('hashlink ${name} algorithms runtime skipped');
        return;
      }

      var scratch:Scratch = null;
      var valuesI32:Tensor<I32> = null;
      var outI32:Tensor<I32> = null;
      var valuesU32:Tensor<U32> = null;
      var outU32:Tensor<U32> = null;
      var valuesI64:Tensor<I64> = null;
      var outI64:Tensor<I64> = null;
      var valuesU64:Tensor<U64> = null;
      var outU64:Tensor<U64> = null;
      var valuesF32:Tensor<F32> = null;
      var outF32:Tensor<F32> = null;
      var valuesF64:Tensor<F64> = null;
      var outF64:Tensor<F64> = null;
      var flags:Tensor<I32> = null;
      var countOut:Tensor<I32> = null;
      var keys:Tensor<I32> = null;
      var outKeys:Tensor<I32> = null;
      var radixU32Keys:Tensor<U32> = null;
      var radixU32OutKeys:Tensor<U32> = null;
      var radixI64Keys:Tensor<I64> = null;
      var radixI64OutKeys:Tensor<I64> = null;
      var pairValues:Tensor<I32> = null;
      var pairOutValues:Tensor<I32> = null;
      var pairF64Values:Tensor<F64> = null;
      var pairF64OutValues:Tensor<F64> = null;
      var prefix:PrefixSumExecutor = null;
      try {
        scratch = new Scratch(ctx);
        var scratchA = scratch.i32(4);
        var scratchB = scratch.i32(2);
        if (scratchA != scratchB) throw "scratch_i32_reuse";
        var scratchC = scratch.i32(8);
        if (scratchC == scratchA) throw "scratch_i32_growth";
        var scratchU32A = scratch.u32(4);
        var scratchU32B = scratch.u32(2);
        if (scratchU32A != scratchU32B) throw "scratch_u32_reuse";
        scratch.i64(3);
        scratch.u64(3);
        scratch.f32(3);
        scratch.f64(3);
        scratch.reset();

        valuesI32 = new Tensor<I32>(ctx, [6]);
        outI32 = new Tensor<I32>(ctx, [6]);
        valuesI32.fromArray([3, -1, 5, 2, 5, 4]);
        outI32.fill(0);
        Reduce.deviceReduceAdd(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_add_i32", outI32.read(0), 18);
        Reduce.addI32(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_add_i32_typed", outI32.read(0), 18);
        Reduce.deviceReduceMin(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_min_i32", outI32.read(0), -1);
        Reduce.deviceReduceMax(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_max_i32", outI32.read(0), 5);

        Scan.deviceExclusiveScanAdd(valuesI32, outI32);
        ctx.sync();
        expectArrayI32("scan_i32", outI32, [0, 3, 2, 7, 9, 14]);
        Scan.exclusiveAddI32(valuesI32, outI32);
        ctx.sync();
        expectArrayI32("scan_i32_typed", outI32, [0, 3, 2, 7, 9, 14]);
        Scan.deviceExclusiveScanMin(valuesI32, outI32);
        ctx.sync();
        expectArrayI32("scan_min_i32", outI32, [2147483647, 3, -1, -1, -1, -1]);
        Scan.deviceExclusiveScanMax(valuesI32, outI32);
        ctx.sync();
        expectArrayI32("scan_max_i32", outI32, [-2147483647 - 1, 3, 3, 5, 5, 5]);
        prefix = new PrefixSumExecutor(ctx);
        prefix.deviceExclusiveScanAdd(valuesI32, outI32);
        ctx.sync();
        prefix.close();
        prefix = null;
        expectArrayI32("prefix_executor_i32", outI32, [0, 3, 2, 7, 9, 14]);

        flags = new Tensor<I32>(ctx, [6]);
        countOut = new Tensor<I32>(ctx, [1]);
        flags.fromArray([1, 0, 1, 1, 0, 1]);
        outI32.fill(0);
        countOut.fill(0);
        Select.deviceSelect(valuesI32, flags, outI32, countOut);
        ctx.sync();
        expectEq("select_count", countOut.read(0), 4);
        expectArrayI32("select_i32", outI32, [3, 5, 2, 4]);

        Sort.parallelSort(valuesI32, -1, true);
        ctx.sync();
        expectArrayI32("sort_i32_ascending", valuesI32, [-1, 2, 3, 4, 5, 5]);
        Sort.parallelSort(valuesI32, -1, false);
        ctx.sync();
        expectArrayI32("sort_i32_descending", valuesI32, [5, 5, 4, 3, 2, -1]);
        Sort.deviceRadixSort(valuesI32, outI32, -1, true);
        ctx.sync();
        expectArrayI32("radix_i32", outI32, [-1, 2, 3, 4, 5, 5]);

        keys = new Tensor<I32>(ctx, [6]);
        outKeys = new Tensor<I32>(ctx, [6]);
        keys.fromArray([2, 1, 2, 1, 3, 2]);
        valuesI32.fromArray([10, 1, 20, 2, 7, 30]);
        outI32.fill(0);
        countOut.fill(0);
        ReduceByKey.deviceReduceByKeyAdd(keys, valuesI32, outKeys, outI32, countOut);
        ctx.sync();
        expectEq("reduce_by_key_consecutive_count", countOut.read(0), 6);
        expectArrayI32("reduce_by_key_consecutive_keys", outKeys, [2, 1, 2, 1, 3, 2]);
        expectArrayI32("reduce_by_key_consecutive_values", outI32, [10, 1, 20, 2, 7, 30]);
        outI32.fill(0);
        countOut.fill(0);
        ReduceByKey.reduceByKeyGlobalAdd(keys, valuesI32, outKeys, outI32, countOut);
        ctx.sync();
        expectEq("reduce_by_key_global_count", countOut.read(0), 3);
        expectArrayI32("reduce_by_key_global_keys", outKeys, [2, 1, 3]);
        expectArrayI32("reduce_by_key_global_values", outI32, [60, 3, 7]);
        keys.fromArray([2, 2, 1, 1, 2, 3]);
        valuesI32.fromArray([10, 20, 1, 2, 30, 7]);
        outI32.fill(0);
        countOut.fill(0);
        ReduceByKey.deviceReduceByKeyAdd(keys, valuesI32, outKeys, outI32, countOut);
        ctx.sync();
        expectEq("reduce_by_key_run_count", countOut.read(0), 4);
        expectArrayI32("reduce_by_key_run_keys", outKeys, [2, 1, 2, 3]);
        expectArrayI32("reduce_by_key_run_values", outI32, [30, 3, 30, 7]);

        valuesU32 = new Tensor<U32>(ctx, [4]);
        outU32 = new Tensor<U32>(ctx, [4]);
        valuesU32.fromArray([i64(3), i64(7), i64(2), i64(4)]);
        Reduce.deviceReduceAdd(valuesU32, outU32);
        ctx.sync();
        expectInt64("reduce_add_u32", outU32.read(0), i64(16));
        Reduce.deviceReduceMin(valuesU32, outU32);
        ctx.sync();
        expectInt64("reduce_min_u32", outU32.read(0), i64(2));
        Reduce.deviceReduceMax(valuesU32, outU32);
        ctx.sync();
        expectInt64("reduce_max_u32", outU32.read(0), i64(7));
        Scan.deviceExclusiveScanAdd(valuesU32, outU32);
        ctx.sync();
        expectArrayU32("scan_u32", outU32, [i64(0), i64(3), i64(10), i64(12)]);
        Scan.deviceExclusiveScanMin(valuesU32, outU32);
        ctx.sync();
        expectArrayU32("scan_min_u32", outU32, [Int64.make(0, -1), i64(3), i64(3), i64(2)]);
        Scan.deviceExclusiveScanMax(valuesU32, outU32);
        ctx.sync();
        expectArrayU32("scan_max_u32", outU32, [i64(0), i64(3), i64(7), i64(7)]);
        Select.deviceSelect(valuesU32, flags, outU32, countOut, 4);
        ctx.sync();
        expectEq("select_count_u32", countOut.read(0), 3);
        expectArrayU32("select_u32", outU32, [i64(3), i64(2), i64(4)]);
        valuesU32.fromArray([i64(3), Int64.make(0, -1), i64(2), i64(4)]);
        Sort.parallelSort(valuesU32, -1, true);
        ctx.sync();
        expectArrayU32("sort_u32", valuesU32, [i64(2), i64(3), i64(4), Int64.make(0, -1)]);

        valuesI64 = new Tensor<I64>(ctx, [4]);
        outI64 = new Tensor<I64>(ctx, [4]);
        valuesI64.fromArray([i64(3), i64(-1), i64(5), i64(2)]);
        Reduce.deviceReduceAdd(valuesI64, outI64);
        ctx.sync();
        expectInt64("reduce_add_i64", outI64.read(0), i64(9));
        Reduce.deviceReduceMin(valuesI64, outI64);
        ctx.sync();
        expectInt64("reduce_min_i64", outI64.read(0), i64(-1));
        Reduce.deviceReduceMax(valuesI64, outI64);
        ctx.sync();
        expectInt64("reduce_max_i64", outI64.read(0), i64(5));
        Scan.deviceExclusiveScanAdd(valuesI64, outI64);
        ctx.sync();
        expectArrayI64("scan_i64", outI64, [i64(0), i64(3), i64(2), i64(7)]);
        Scan.deviceExclusiveScanMin(valuesI64, outI64);
        ctx.sync();
        expectArrayI64("scan_min_i64", outI64, [i64Max(), i64(3), i64(-1), i64(-1)]);
        Scan.deviceExclusiveScanMax(valuesI64, outI64);
        ctx.sync();
        expectArrayI64("scan_max_i64", outI64, [i64Min(), i64(3), i64(3), i64(5)]);
        Select.deviceSelect(valuesI64, flags, outI64, countOut, 4);
        ctx.sync();
        expectEq("select_count_i64", countOut.read(0), 3);
        expectArrayI64("select_i64", outI64, [i64(3), i64(5), i64(2)]);
        Sort.parallelSort(valuesI64, -1, true);
        ctx.sync();
        expectArrayI64("sort_i64", valuesI64, [i64(-1), i64(2), i64(3), i64(5)]);

        valuesU64 = new Tensor<U64>(ctx, [4]);
        outU64 = new Tensor<U64>(ctx, [4]);
        valuesU64.fromArray([i64(3), i64(7), i64(2), i64(4)]);
        Reduce.deviceReduceAdd(valuesU64, outU64);
        ctx.sync();
        expectInt64("reduce_add_u64", outU64.read(0), i64(16));
        Reduce.deviceReduceMin(valuesU64, outU64);
        ctx.sync();
        expectInt64("reduce_min_u64", outU64.read(0), i64(2));
        Reduce.deviceReduceMax(valuesU64, outU64);
        ctx.sync();
        expectInt64("reduce_max_u64", outU64.read(0), i64(7));
        Scan.deviceExclusiveScanAdd(valuesU64, outU64);
        ctx.sync();
        expectArrayU64("scan_u64", outU64, [i64(0), i64(3), i64(10), i64(12)]);
        Scan.deviceExclusiveScanMin(valuesU64, outU64);
        ctx.sync();
        expectArrayU64("scan_min_u64", outU64, [Int64.make(-1, -1), i64(3), i64(3), i64(2)]);
        Scan.deviceExclusiveScanMax(valuesU64, outU64);
        ctx.sync();
        expectArrayU64("scan_max_u64", outU64, [i64(0), i64(3), i64(7), i64(7)]);
        Select.deviceSelect(valuesU64, flags, outU64, countOut, 4);
        ctx.sync();
        expectEq("select_count_u64", countOut.read(0), 3);
        expectArrayU64("select_u64", outU64, [i64(3), i64(2), i64(4)]);
        valuesU64.fromArray([i64(3), Int64.make(-1, -1), i64(2), i64(4)]);
        Sort.parallelSort(valuesU64, -1, true);
        ctx.sync();
        expectArrayU64("sort_u64", valuesU64, [i64(2), i64(3), i64(4), Int64.make(-1, -1)]);

        valuesF32 = new Tensor<F32>(ctx, [4]);
        outF32 = new Tensor<F32>(ctx, [4]);
        valuesF32.fromArray([1.5, -2.0, 3.25, 0.25]);
        outF32.fill(0.0);
        Reduce.deviceReduceAdd(valuesF32, outF32);
        ctx.sync();
        expectNear("reduce_add_f32", outF32.read(0), 3.0);
        Scan.deviceExclusiveScanAdd(valuesF32, outF32);
        ctx.sync();
        expectArrayF32("scan_f32", outF32, [0.0, 1.5, -0.5, 2.75]);
        Scan.deviceExclusiveScanMin(valuesF32, outF32);
        ctx.sync();
        var minIdentity:Float = outF32.read(0);
        expectTrue("scan_min_f32_identity", minIdentity > 1e30);
        expectArrayF32("scan_min_f32_tail", outF32, [minIdentity, 1.5, -2.0, -2.0]);
        Scan.deviceExclusiveScanMax(valuesF32, outF32);
        ctx.sync();
        var maxIdentity:Float = outF32.read(0);
        expectTrue("scan_max_f32_identity", maxIdentity < -1e30);
        expectArrayF32("scan_max_f32_tail", outF32, [maxIdentity, 1.5, 1.5, 3.25]);
        Sort.parallelSort(valuesF32, -1, true);
        ctx.sync();
        expectArrayF32("sort_f32", valuesF32, [-2.0, 0.25, 1.5, 3.25]);

        valuesF64 = new Tensor<F64>(ctx, [4]);
        outF64 = new Tensor<F64>(ctx, [4]);
        valuesF64.fromArray([1.5, -2.0, 3.25, 0.25]);
        Reduce.deviceReduceAdd(valuesF64, outF64);
        ctx.sync();
        expectNear("reduce_add_f64", outF64.read(0), 3.0);
        Reduce.deviceReduceMin(valuesF64, outF64);
        ctx.sync();
        expectNear("reduce_min_f64", outF64.read(0), -2.0);
        Reduce.deviceReduceMax(valuesF64, outF64);
        ctx.sync();
        expectNear("reduce_max_f64", outF64.read(0), 3.25);
        Scan.deviceExclusiveScanAdd(valuesF64, outF64);
        ctx.sync();
        expectArrayF64("scan_f64", outF64, [0.0, 1.5, -0.5, 2.75]);
        Scan.deviceExclusiveScanMin(valuesF64, outF64);
        ctx.sync();
        var minIdentityF64:Float = outF64.read(0);
        expectTrue("scan_min_f64_identity", minIdentityF64 > 1e300);
        expectArrayF64("scan_min_f64_tail", outF64, [minIdentityF64, 1.5, -2.0, -2.0]);
        Scan.deviceExclusiveScanMax(valuesF64, outF64);
        ctx.sync();
        var maxIdentityF64:Float = outF64.read(0);
        expectTrue("scan_max_f64_identity", maxIdentityF64 < -1e300);
        expectArrayF64("scan_max_f64_tail", outF64, [maxIdentityF64, 1.5, 1.5, 3.25]);
        Select.deviceSelect(valuesF64, flags, outF64, countOut, 4);
        ctx.sync();
        expectEq("select_count_f64", countOut.read(0), 3);
        expectArrayF64("select_f64", outF64, [1.5, 3.25, 0.25]);
        Sort.parallelSort(valuesF64, -1, true);
        ctx.sync();
        expectArrayF64("sort_f64", valuesF64, [-2.0, 0.25, 1.5, 3.25]);

        radixU32Keys = new Tensor<U32>(ctx, [5]);
        radixU32OutKeys = new Tensor<U32>(ctx, [5]);
        pairValues = new Tensor<I32>(ctx, [5]);
        pairOutValues = new Tensor<I32>(ctx, [5]);
        radixU32Keys.fromArray([Int64.make(0, 0x21), Int64.make(0, 0x13), Int64.make(0, 0x02), Int64.make(0, 0x11), Int64.make(0, 0x22)]);
        pairValues.fromArray([10, 20, 30, 40, 50]);
        Sort.deviceRadixSortPairs(radixU32Keys, pairValues, radixU32OutKeys, pairOutValues, -1, true, 0, 4);
        ctx.sync();
        expectArrayU32("radix_pairs_u32_keys", radixU32OutKeys, [Int64.make(0, 0x21), Int64.make(0, 0x11), Int64.make(0, 0x02), Int64.make(0, 0x22), Int64.make(0, 0x13)]);
        expectArrayI32("radix_pairs_u32_values", pairOutValues, [10, 40, 30, 50, 20]);
        pairF64Values = new Tensor<F64>(ctx, [5]);
        pairF64OutValues = new Tensor<F64>(ctx, [5]);
        pairF64Values.fromArray([1.0, 2.0, 3.0, 4.0, 5.0]);
        Sort.deviceRadixSortPairs(radixU32Keys, pairF64Values, radixU32OutKeys, pairF64OutValues, -1, true, 0, 4);
        ctx.sync();
        expectArrayF64("radix_pairs_u32_f64_values", pairF64OutValues, [1.0, 4.0, 3.0, 5.0, 2.0]);

        radixI64Keys = new Tensor<I64>(ctx, [4]);
        radixI64OutKeys = new Tensor<I64>(ctx, [4]);
        radixI64Keys.fromArray([i64(3), i64(-1), i64(2), i64(-5)]);
        Sort.deviceRadixSort(radixI64Keys, radixI64OutKeys, -1, true);
        ctx.sync();
        expectArrayI64("radix_i64", radixI64OutKeys, [i64(-5), i64(-1), i64(2), i64(3)]);
      } catch (e:Dynamic) {
        if (prefix != null) prefix.close();
        closeTensor(pairF64OutValues);
        closeTensor(pairF64Values);
        closeTensor(pairOutValues);
        closeTensor(pairValues);
        closeTensor(radixI64OutKeys);
        closeTensor(radixI64Keys);
        closeTensor(radixU32OutKeys);
        closeTensor(radixU32Keys);
        closeTensor(outKeys);
        closeTensor(keys);
        closeTensor(countOut);
        closeTensor(flags);
        closeTensor(outF64);
        closeTensor(valuesF64);
        closeTensor(outF32);
        closeTensor(valuesF32);
        closeTensor(outU64);
        closeTensor(valuesU64);
        closeTensor(outI64);
        closeTensor(valuesI64);
        closeTensor(outU32);
        closeTensor(valuesU32);
        closeTensor(outI32);
        closeTensor(valuesI32);
        if (scratch != null) scratch.close();
        throw e;
      }
      if (prefix != null) prefix.close();
      closeTensor(pairF64OutValues);
      closeTensor(pairF64Values);
      closeTensor(pairOutValues);
      closeTensor(pairValues);
      closeTensor(radixI64OutKeys);
      closeTensor(radixI64Keys);
      closeTensor(radixU32OutKeys);
      closeTensor(radixU32Keys);
      closeTensor(outKeys);
      closeTensor(keys);
      closeTensor(countOut);
      closeTensor(flags);
      closeTensor(outF64);
      closeTensor(valuesF64);
      closeTensor(outF32);
      closeTensor(valuesF32);
      closeTensor(outU64);
      closeTensor(valuesU64);
      closeTensor(outI64);
      closeTensor(valuesI64);
      closeTensor(outU32);
      closeTensor(valuesU32);
      closeTensor(outI32);
      closeTensor(valuesI32);
      scratch.close();
    });
  }
}
