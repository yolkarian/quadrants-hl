import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class TestProfilerRuntime {
  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  public static function run():Void {
    TestRuntimeSupport.closeSharedContexts();
    var ctx = new Context(Arch.Cpu, true);
    var kernel:Kernel = null;
    var out:Tensor<I32> = null;
    try {
      out = new Tensor<I32>(ctx, [1]);
      kernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
        out[0] = 1;
      });
      kernel.launch(out);
      kernel.launch(out);
      ctx.sync();
      var profiler = ctx.profiler();
      var record = profiler.recordKernel(kernel);
      expectTrue('profiler_record_kernel_count', record.count >= 2);
      expectTrue('profiler_record_kernel_min', record.minTime >= 0.0);
      expectTrue('profiler_record_kernel_max', record.maxTime >= record.minTime);
      expectTrue('profiler_record_kernel_avg', (record.count == 0) || (record.averageTime >= record.minTime && record.averageTime <= record.maxTime));
      expectTrue('kernel_name_unique_prefix', StringTools.startsWith(kernel.kernelName(), 'haxe_kernel_'));
      kernel.close();
      out.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (out != null) out.close();
      if (kernel != null) kernel.close();
      ctx.close();
      throw e;
    }
  }
}
