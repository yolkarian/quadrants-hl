import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;

class TestAtomic {
  static inline final FETCH_ADD_N = 32;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  static function runOnContext(ctx:Context):Void {
    var k:Kernel = null;
    try {
      var out = new Tensor<I32>(ctx, [1]);
      out.fill(0);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[0] += 1;
        }
      });
      k.launch(out, 32);
      ctx.sync();
      expectEq('atomic_add', out.read(0), 32);
      k.close();
      k = null;

      out.fill(40);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[0] -= 1;
        }
      });
      k.launch(out, 8);
      ctx.sync();
      expectEq('atomic_sub', out.read(0), 32);
      k.close();
      k = null;

      var counts = new Tensor<I32>(ctx, [1]);
      var seen = new Tensor<I32>(ctx, [FETCH_ADD_N]);
      counts.fill(0);
      seen.fill(0);
      k = Kernel.build(ctx, macro (counts, seen, n) -> {
        for (i in 0...n) {
          var slot = atomicAdd(counts[0], 1);
          if (slot >= 0 && slot < n) {
            seen[slot] += 1;
          }
        }
      });
      k.launch(counts, seen, FETCH_ADD_N);
      ctx.sync();
      expectEq('atomic_fetch_add_count', counts.read(0), FETCH_ADD_N);
      for (i in 0...FETCH_ADD_N) {
        expectEq('atomic_fetch_add_seen[${i}]', seen.read(i), 1);
      }
      k.close();
      k = null;

      var ops = new Tensor<I32>(ctx, [18]);
      ops.fromArray([3, 0, 9, 0, 9, 0, 12, 0, 5, 0, 15, 0, 6, 0, 5, 0, 11, 0]);
      k = Kernel.build(ctx, macro (ops:Tensor<I32>) -> {
        for (i in 0...1) {
          ops[1] = atomicMul(ops[0], 4);
          ops[3] = atomicMin(ops[2], 4);
          ops[5] = atomicMax(ops[4], 12);
          ops[7] = atomicAnd(ops[6], 10);
          ops[9] = atomicOr(ops[8], 10);
          ops[11] = atomicXor(ops[10], 5);
          ops[13] = atomicExchange(ops[12], 2);
          ops[15] = atomicCompareExchange(ops[14], 5, 9);
          ops[17] = atomicCompareExchange(ops[16], 5, 7);
        }
      });
      k.launch(ops);
      ctx.sync();
      expectEq('atomic_mul_value', ops.read(0), 12);
      expectEq('atomic_mul_old', ops.read(1), 3);
      expectEq('atomic_min_value', ops.read(2), 4);
      expectEq('atomic_min_old', ops.read(3), 9);
      expectEq('atomic_max_value', ops.read(4), 12);
      expectEq('atomic_max_old', ops.read(5), 9);
      expectEq('atomic_and_value', ops.read(6), 8);
      expectEq('atomic_and_old', ops.read(7), 12);
      expectEq('atomic_or_value', ops.read(8), 15);
      expectEq('atomic_or_old', ops.read(9), 5);
      expectEq('atomic_xor_value', ops.read(10), 10);
      expectEq('atomic_xor_old', ops.read(11), 15);
      expectEq('atomic_exchange_value', ops.read(12), 2);
      expectEq('atomic_exchange_old', ops.read(13), 6);
      expectEq('atomic_cas_value', ops.read(14), 9);
      expectEq('atomic_cas_old', ops.read(15), 5);
      expectEq('atomic_cas_fail_value', ops.read(16), 11);
      expectEq('atomic_cas_fail_old', ops.read(17), 11);
      k.close();
      k = null;

      var floatOps = new Tensor<F32>(ctx, [6]);
      floatOps.fromArray([1.5, 0.0, 1.0, 0.0, -1.0, 0.0]);
      k = Kernel.build(ctx, macro (floatOps:Tensor<F32>) -> {
        for (i in 0...1) {
          floatOps[1] = atomicAdd(floatOps[0], 0.5);
          floatOps[3] = atomicMin(floatOps[2], 0.25);
          floatOps[5] = atomicMax(floatOps[4], 0.75);
        }
      });
      k.launch(floatOps);
      ctx.sync();
      expectNear('atomic_f32_add_value', floatOps.read(0), 2.0);
      expectNear('atomic_f32_add_old', floatOps.read(1), 1.5);
      expectNear('atomic_f32_min_value', floatOps.read(2), 0.25);
      expectNear('atomic_f32_min_old', floatOps.read(3), 1.0);
      expectNear('atomic_f32_max_value', floatOps.read(4), 0.75);
      expectNear('atomic_f32_max_old', floatOps.read(5), -1.0);
    } catch (e:Dynamic) {
      TestRuntimeSupport.closeKernel(k);
      throw e;
    }
    TestRuntimeSupport.closeKernel(k);
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      runOnContext(ctx);
    });
  }
}
