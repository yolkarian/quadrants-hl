import haxe.Json;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.simt.SubgroupScan;

// Runtime check of the subgroup @:qdFunc helpers on a GPU backend. A 32-lane
// for-loop (one warp, blockDim 32) feeds all-ones into an inclusive add scan,
// which must leave lane i with i + 1.
class SubgroupGpuSemantic {
  static function eq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function main():Void {
    var arch = switch (Sys.getEnv("QD_HASHLINK_TEST_ARCH")) {
      case "cuda": Arch.Cuda;
      case "amdgpu": Arch.Amdgpu;
      case "vulkan": Arch.Vulkan;
      case value: throw 'QD_HASHLINK_TEST_ARCH must be cuda, amdgpu, or vulkan, got ${value}';
    };
    var backend = switch (arch) {
      case Arch.Cuda: "cuda";
      case Arch.Amdgpu: "amdgpu";
      case Arch.Vulkan: "vulkan";
      default: "cpu";
    };
    var ctx:Context = null;
    try {
      ctx = Context.create({arch: arch});
    } catch (e:Dynamic) {
      Sys.println(Json.stringify({test: "hashlink-subgroup-gpu-semantic", backend: backend, skipped: true, reason: Std.string(e)}));
      return;
    }

    try {
      var input = new Tensor<I32>(ctx, [32]);
      var out = new Tensor<I32>(ctx, [32]);
      for (lane in 0...32) input.write(lane, 1);
      out.fill(0);
      var kernel = Kernel.build(ctx, macro (input:Tensor<I32>, out:Tensor<I32>) -> {
        for (i in 0...32) {
          blockDim(32);
          out[i] = SubgroupScan.subgroupInclusiveAddI32(input[i]);
        }
      }, {helpers: [SubgroupScan]});
      kernel.launch(input, out);
      ctx.sync();
      // inclusive add of 32 ones: lane i holds i + 1
      eq("subgroup_inclusive_add_lane0", out.read(0), 1);
      eq("subgroup_inclusive_add_lane1", out.read(1), 2);
      eq("subgroup_inclusive_add_lane15", out.read(15), 16);
      eq("subgroup_inclusive_add_lane31", out.read(31), 32);
      Sys.println(Json.stringify({test: "hashlink-subgroup-gpu-semantic", backend: backend, passed: true}));
      kernel.close();
      out.close();
      input.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
    ctx.close();
  }
}