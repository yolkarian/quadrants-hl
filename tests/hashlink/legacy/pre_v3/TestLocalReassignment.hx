import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Types.F32;

class TestLocalReassignment {
  static inline final F32_N = 4;
  static inline final INT_N = 8;
  static inline final COUNTER_N = 8;
  static inline final MAX_NEIGHBORS = 5;
  static inline final SCOPE_N = 8;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var kernels:Array<Kernel> = [];
      try {
        var input = new Tensor<F32>(ctx, [F32_N]);
        var outF = new Tensor<F32>(ctx, [F32_N]);
        var fValues = [-1.0, 0.25, 2.0, 7.0];
        var fExpected = [0.0, 0.25, 1.0, 1.0];
        for (i in 0...F32_N) input.write(i, fValues[i]);

        var f32Clamp = Kernel.build(ctx, macro (input:quadrants.Tensor<F32>, outF:quadrants.Tensor<F32>, n:Int, minX:F32, maxX:F32) -> {
          for (i in 0...n) {
            var x:F32 = input[i];
            if (x < minX) x = minX;
            if (x > maxX) x = maxX;
            outF[i] = x;
          }
        });
        kernels.push(f32Clamp);
        f32Clamp.launch(input, outF, F32_N, 0.0, 1.0);
        ctx.sync();
        for (i in 0...F32_N) expectNear('f32_local_reassign[${i}]', outF.read(i), fExpected[i]);

        var pos = new Tensor<F32>(ctx, [INT_N]);
        var outI = new Tensor<I32>(ctx, [INT_N]);
        var posValues = [-2.0, -0.1, 0.0, 0.9, 1.0, 1.9, 2.0, 5.0];
        var intExpected = [0, 0, 0, 0, 1, 1, 2, 2];
        for (i in 0...INT_N) pos.write(i, posValues[i]);

        var intClamp = Kernel.build(ctx, macro (pos:quadrants.Tensor<F32>, outI:quadrants.Tensor<I32>, n:Int, gridMin:F32, cellSize:F32, cellsX:Int) -> {
          for (i in 0...n) {
            var cx = cast(Math.floor((pos[i] - gridMin) / cellSize), Int);
            if (cx < 0) cx = 0;
            if (cx >= cellsX) cx = cellsX - 1;
            outI[i] = cx;
          }
        });
        kernels.push(intClamp);
        intClamp.launch(pos, outI, INT_N, 0.0, 1.0, 3);
        ctx.sync();
        for (i in 0...INT_N) expectEq('int_conditional_reassign[${i}]', outI.read(i), intExpected[i]);

        var counts = new Tensor<I32>(ctx, [COUNTER_N]);
        var neighbors = new Tensor<I32>(ctx, [COUNTER_N * COUNTER_N]);
        counts.fill(-1);
        neighbors.fill(-1);
        var counter = Kernel.build(ctx, macro (counts:quadrants.Tensor<I32>, neighbors:quadrants.Tensor<I32>, n:Int, maxNeighbors:Int) -> {
          for (i in 0...n) {
            var count = 1;
            for (j in 0...n) {
              if (j < i && count < maxNeighbors) {
                neighbors[i * n + count] = j;
                count = count + 1;
              }
            }
            counts[i] = count;
          }
        });
        kernels.push(counter);
        counter.launch(counts, neighbors, COUNTER_N, MAX_NEIGHBORS);
        ctx.sync();
        for (i in 0...COUNTER_N) {
          var expected = i + 1;
          if (expected > MAX_NEIGHBORS) expected = MAX_NEIGHBORS;
          expectEq('nested_counter[${i}]', counts.read(i), expected);
          for (slot in 1...expected) {
            expectEq('nested_neighbor[${i},${slot}]', neighbors.read(i * COUNTER_N + slot), slot - 1);
          }
        }

        var scoped = new Tensor<I32>(ctx, [SCOPE_N]);
        scoped.fill(-1);
        var scopedKernel = Kernel.build(ctx, macro (out:quadrants.Tensor<I32>) -> {
          var x = 1;
          out[0] = x;
          {
            var x = 7;
            out[1] = x;
            x = x + 1;
            out[2] = x;
          }
          out[3] = x;
          for (i in 0...2) {
            var x = i + 10;
            out[4 + i] = x;
          }
          out[6] = x;
        });
        kernels.push(scopedKernel);
        scopedKernel.launch(scoped);
        ctx.sync();
        var scopeExpected = [1, 7, 8, 1, 10, 11, 1, -1];
        for (i in 0...SCOPE_N) expectEq('scoped_local_shadow[${i}]', scoped.read(i), scopeExpected[i]);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
    });
  }
}
