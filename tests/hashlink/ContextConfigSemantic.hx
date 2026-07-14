import quadrants.CacheCleanPolicy;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.OptLevel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class ContextConfigSemantic {
  static function expect(name:String, condition:Bool):Void {
    if (!condition) {
      throw 'ContextConfigSemantic ${name} failed';
    }
  }

  public static function run():Void {
    var ctx = Context.create({
      arch: Arch.Cpu,
      boundsCheck: true,
      offlineCache: {
        enabled: true,
        path: "/tmp/qd-ctxconfig-cache",
        cleanPolicy: CacheCleanPolicy.Fifo,
        maxSizeBytes: haxe.Int64.ofInt(16 * 1024 * 1024),
        cleanFactor: 0.5,
      },
      compile: {
        cfgOptimization: true,
        numThreads: 2,
        optLevel: OptLevel.O2,
        externalOptLevel: OptLevel.O1,
      },
      debug: {
        launchDebug: false,
        timeline: true,
      },
      memory: {
        deviceMemoryFraction: 0.5,
        cudaStackLimitBytes: 8192,
      },
    });
    try {
      expect("no_option_warnings", ctx.optionWarnings().length == 0);
      var options = ctx.currentOptions();
      expect("clean_policy_recorded", (options.offlineCacheCleanPolicy : String) == "fifo");
      expect("clean_factor_recorded", options.offlineCacheCleanFactor == 0.5);
      expect("compile_threads_recorded", options.compileNumThreads == 2);
      expect("opt_level_recorded", (options.compileOptLevel : String) == "O2");
      expect("external_opt_level_recorded", (options.compileExternalOptLevel : String) == "O1");
      expect("timeline_recorded", options.debugTimelineEnabled == true);
      expect("memory_fraction_recorded", options.deviceMemoryFraction == 0.5);
      expect("cuda_stack_recorded", options.cudaStackLimitBytes == 8192);

      Context.timelineClear();
      var input = new Tensor<I32>(ctx, [4]);
      var out = new Tensor<I32>(ctx, [4]);
      input.fromArray([1, 2, 3, 4]);
      var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
        for (i in 0...4) {
          out[i] = a[i] * 2;
        }
      });
      k.launch(input, out);
      ctx.sync();
      var values = out.toArray();
      expect("kernel_result", values[0] == 2 && values[3] == 8);

      var timelinePath = "/tmp/qd-ctxconfig-timeline.json";
      if (sys.FileSystem.exists(timelinePath)) {
        sys.FileSystem.deleteFile(timelinePath);
      }
      Context.timelineSave(timelinePath);
      expect("timeline_saved", sys.FileSystem.exists(timelinePath));
      sys.FileSystem.deleteFile(timelinePath);

      var invalidRejected = false;
      try {
        ctx.setOfflineCacheCleanFactor(2.0);
      } catch (e:Dynamic) {
        invalidRejected = true;
      }
      expect("invalid_clean_factor_rejected", invalidRejected);

      var invalidOpt = false;
      try {
        Context.create({arch: Arch.Cpu, compile: {numThreads: 0}});
      } catch (e:Dynamic) {
        invalidOpt = true;
      }
      expect("invalid_compile_threads_rejected", invalidOpt);

      input.close();
      out.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
    ctx.close();
  }

  static function main():Void {
    run();
    Sys.println("context config semantic ok");
  }
}
