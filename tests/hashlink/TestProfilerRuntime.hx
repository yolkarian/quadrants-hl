import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.ContextOptions;
import quadrants.Extension;
import quadrants.profiler.CuptiMetric;
import quadrants.profiler.CuptiMetricPreset;
import quadrants.profiler.ProfilerAvailability;
import quadrants.profiler.ProfilerBridge;
import quadrants.profiler.ProfilerPrintMode;
import quadrants.profiler.ProfilerToolkit;

class TestProfilerRuntime {
  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function testProfilerRecordClear():Void {
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
      profiler.printInfo(ProfilerPrintMode.Count);
      quadrants.profiler.KernelProfiler.printInfo(ctx, ProfilerPrintMode.Trace);
      profiler.clearInfo();
      var cleared = profiler.recordKernel(kernel);
      if (cleared.count != 0) throw 'profiler_clear_count: ${cleared.count}';
      if (profiler.totalTime() != 0.0) throw 'profiler_clear_total_time: ${profiler.totalTime()}';
      var defaultMetrics = CuptiMetric.preset(CuptiMetricPreset.Default);
      if (defaultMetrics.length != 1 || defaultMetrics[0].nativeName() != "dram__bytes.sum") {
        throw "profiler_default_metric_preset";
      }
      if (profiler.setToolkit(ProfilerToolkit.Cupti)) throw "profiler_cupti_toolkit_unexpected_on_cpu";
      if (profiler.setMetricPreset(CuptiMetricPreset.GlobalAccess)) throw "profiler_cupti_metrics_unexpected_on_cpu";
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

  static function testContextOptionsAndExtensions():Void {
    TestRuntimeSupport.closeSharedContexts();
    var cachePath = "build/hashlink-context-options-cache";
    var options = ContextOptions.create()
      .withProfiler(true)
      .withOfflineCache(true, cachePath)
      .withAdstackConfig(true, 0, 0)
      .withRandomSeed(1234)
      .withCpuMaxNumThreads(1)
      .withFastMath(false)
      .withBoundsCheck(true);
    var ctx = Context.fromOptions(options, Arch.Cpu);
    try {
      var features = ProfilerBridge.features(ctx);
      expectTrue("context_options_profiler_enabled", features.enabled);
      expectTrue("context_options_offline_cache_enabled", ctx.offlineCacheEnabled);
      if (ctx.offlineCachePath != cachePath) throw "context_options_offline_cache_path";
      expectTrue("extension_kernel_profiler", ctx.isExtensionEnabled(Extension.KernelProfiler));
      expectTrue("extension_scoped_profiler", ctx.isExtensionEnabled(Extension.ScopedProfiler));
      expectTrue("extension_zero_copy", ctx.isExtensionEnabled(Extension.ZeroCopy));
      expectTrue("extension_external_pointer", ctx.isExtensionEnabled(Extension.ExternalPointerImport));
      if (ctx.isExtensionEnabled(Extension.Cuda)) throw "extension_cuda_unexpected_on_cpu";
      if (ctx.isExtensionEnabled(Extension.CudaGlInterop)) throw "extension_cuda_gl_unexpected_on_cpu";
      if (ctx.isExtensionEnabled(Extension.MemoryProfiler)) throw "extension_memory_profiler_unexpected";
      ctx.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
  }

  static function testMemoryProfilerUnavailable():Void {
    TestRuntimeSupport.closeSharedContexts();
    var ctx = new Context(Arch.Cpu, true);
    try {
      var probe = quadrants.profiler.MemoryProfiler.probe(ctx);
      if (probe.availability != ProfilerAvailability.Unavailable) throw "memory_profiler_probe_available";
      expectTrue("memory_profiler_probe_reason", probe.reason.length > 0);
      var printProbe = quadrants.profiler.MemoryProfiler.printInfo(ctx);
      if (printProbe.availability != ProfilerAvailability.Unavailable) throw "memory_profiler_print_available";
      expectTrue("memory_profiler_print_reason", printProbe.reason.length > 0);
      ctx.close();
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
  }

  public static function run():Void {
    testProfilerRecordClear();
    testContextOptionsAndExtensions();
    testMemoryProfilerUnavailable();
  }
}
