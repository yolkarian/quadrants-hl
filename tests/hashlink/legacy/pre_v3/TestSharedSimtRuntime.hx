import quadrants.Block;
import quadrants.Kernel;
import quadrants.Shared;
import quadrants.Subgroup;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Workgroup;

class TestSharedSimtRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRequestedDeviceContext(function(_name, ctx) {
      var kernels:Array<Kernel> = [];
      try {
        var sharedOut = new Tensor<I32>(ctx, [1]);
        var sharedKernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
          var scratch = Shared.arrayI32(4);
          scratch[0] = 7;
          var tile = Shared.tile16I32();
          tile[15] = scratch[0];
          var flags = Shared.arrayU1(2);
          flags[0] = true;
          out[0] = tile[15] + (flags[0] ? 1 : 0);
        });
        kernels.push(sharedKernel);
        sharedKernel.launch(sharedOut);
        ctx.sync();
        expectEq("shared_runtime", sharedOut.read(0), 8);

        var simtOut = new Tensor<I32>(ctx, [1]);
        var simtKernel = Kernel.build(ctx, macro (out:Tensor<I32>, value:Int) -> {
          Block.sync();
          Block.memFence();
          Workgroup.sync();
          Workgroup.memFence();
          Workgroup.gridMemFence();
          Subgroup.sync();
          Subgroup.memFence();
          var lane = Subgroup.invocationId();
          var size = Subgroup.size();
          var elect = Subgroup.elect();
          var localId = Workgroup.localInvocationId();
          var globalId = Workgroup.globalInvocationId();
          var blockIdx = Block.threadIdx();
          var shuffled = Subgroup.shuffle(value, lane);
          var up = Subgroup.shuffleUp(shuffled, 0);
          var down = Subgroup.shuffleDown(up, 0);
          var broadcast = Subgroup.broadcast(down, lane);
          var all = Block.barrierAnd(1);
          var any = Block.barrierOr(1);
          var count = Block.barrierCount(1);
          out[0] = (blockIdx >= 0 ? 1 : 0)
            + (size > 0 ? 1 : 0)
            + (localId >= 0 ? 1 : 0)
            + (globalId >= 0 ? 1 : 0)
            + (broadcast == value ? 1 : 0)
            + (all == 1 ? 1 : 0)
            + (any == 1 ? 1 : 0)
            + (count > 0 ? 1 : 0)
            + (elect >= 0 ? 1 : 0);
        });
        kernels.push(simtKernel);
        simtKernel.launch(simtOut, 7);
        ctx.sync();
        expectEq("simt_runtime", simtOut.read(0), 9);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
    });
  }
}
