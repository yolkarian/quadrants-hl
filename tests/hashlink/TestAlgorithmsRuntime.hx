import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;
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

  static function expectArrayF32(name:String, tensor:Tensor<F32>, expected:Array<Float>):Void {
    for (i in 0...expected.length) {
      expectNear('${name}_${i}', tensor.read(i), expected[i]);
    }
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
      var valuesF32:Tensor<F32> = null;
      var outF32:Tensor<F32> = null;
      var flags:Tensor<I32> = null;
      var countOut:Tensor<I32> = null;
      var keys:Tensor<I32> = null;
      var outKeys:Tensor<I32> = null;
      var prefix:PrefixSumExecutor = null;
      try {
        scratch = new Scratch(ctx);
        var scratchA = scratch.i32(4);
        var scratchB = scratch.i32(2);
        if (scratchA != scratchB) throw "scratch_i32_reuse";
        var scratchC = scratch.i32(8);
        if (scratchC == scratchA) throw "scratch_i32_growth";
        scratch.f32(3);
        scratch.reset();

        valuesI32 = new Tensor<I32>(ctx, [6]);
        outI32 = new Tensor<I32>(ctx, [6]);
        valuesI32.fromArray([3, -1, 5, 2, 5, 4]);
        outI32.fill(0);
        Reduce.deviceReduceAdd(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_add_i32", outI32.read(0), 18);
        Reduce.deviceReduceMin(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_min_i32", outI32.read(0), -1);
        Reduce.deviceReduceMax(valuesI32, outI32);
        ctx.sync();
        expectEq("reduce_max_i32", outI32.read(0), 5);

        Scan.deviceExclusiveScanAdd(valuesI32, outI32);
        ctx.sync();
        expectArrayI32("scan_i32", outI32, [0, 3, 2, 7, 9, 14]);
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
        expectEq("reduce_by_key_count", countOut.read(0), 3);
        expectArrayI32("reduce_by_key_keys", outKeys, [2, 1, 3]);
        expectArrayI32("reduce_by_key_values", outI32, [60, 3, 7]);

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
      } catch (e:Dynamic) {
        if (prefix != null) prefix.close();
        if (outKeys != null) outKeys.close();
        if (keys != null) keys.close();
        if (countOut != null) countOut.close();
        if (flags != null) flags.close();
        if (outF32 != null) outF32.close();
        if (valuesF32 != null) valuesF32.close();
        if (outI32 != null) outI32.close();
        if (valuesI32 != null) valuesI32.close();
        if (scratch != null) scratch.close();
        throw e;
      }
      if (prefix != null) prefix.close();
      outKeys.close();
      keys.close();
      countOut.close();
      flags.close();
      outF32.close();
      valuesF32.close();
      outI32.close();
      valuesI32.close();
      scratch.close();
    });
  }
}
