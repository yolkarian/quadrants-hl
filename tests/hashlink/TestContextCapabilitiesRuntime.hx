import quadrants.CacheCleanPolicy;
import haxe.Json;
import quadrants.Context;
import quadrants.ContextOptions;
import quadrants.Extension;
import quadrants.Kernel;
import quadrants.OptLevel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.I32;
import quadrants.compat.Diagnostics;
import quadrants.linalg.SparseBackendFeatures;
import sys.io.File;

class TestContextCapabilitiesRuntime {
  static function expectEq(name:String, got:Dynamic, expected:Dynamic):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) {
      throw '${name}: expected true';
    }
  }

  static function containsSubstring(values:Array<String>, needle:String):Bool {
    for (value in values) {
      if (value.indexOf(needle) >= 0) {
        return true;
      }
    }
    return false;
  }

  static function manifestVersion():String {
    var manifest:Dynamic = Json.parse(File.getContent("bindings/hashlink/haxelib.json"));
    return cast Reflect.field(manifest, "version");
  }

  public static function run():Void {
    var opts = ContextOptions.builder()
      .arch(Arch.Cpu)
      .offlineCache({enabled: true, path: "build/hashlink-cache", cleanPolicy: CacheCleanPolicy.Lru})
      .compile({cfgOptimization: true, numCompileThreads: 2, optLevel: OptLevel.O2, externalOptLevel: OptLevel.O1})
      .defaults({fp: DType.F32, ip: DType.I32, up: DType.U32})
      .memory({deviceMemoryFraction: 0.5, cudaStackLimitBytes: 1024})
      .ad({experimental: true, stackSize: 4096, sparseThresholdBytes: 2048})
      .debug({path: "/tmp/quadrants-capabilities", printIr: false, launchDebug: true, timeline: true})
      .warnOnFieldMirrorFallback(true)
      .build();

    var ctx:Context = null;
    var kernel:Kernel = null;
    var probeTensor:Tensor<I32> = null;
    try {
      // options.arch should take precedence over the positional fallback passed to fromOptions(...).
      ctx = Context.fromOptions(opts, Arch.Cuda);
      expectEq("context_builder_arch", ctx.arch, Arch.Cpu);
      expectEq("context_current_compile_threads", ctx.currentOptions().compileNumThreads, 2);
      expectEq("context_current_opt_level", ctx.currentOptions().compileOptLevel, OptLevel.O2);
      expectEq("context_current_warn_field_mirror", ctx.currentOptions().warnOnFieldMirrorFallbackEnabled, true);
      expectTrue("context_option_warning_cfg", containsSubstring(ctx.optionWarnings(), "ContextOptions.compile.cfgOptimization"));
      expectTrue("context_option_warning_threads", containsSubstring(ctx.optionWarnings(), "ContextOptions.compile.numCompileThreads"));
      expectTrue("context_option_warning_defaults", containsSubstring(ctx.optionWarnings(), "ContextOptions.defaults"));

      var caps = ctx.capabilities();
      probeTensor = new Tensor<I32>(ctx, [1]);
      var sparseFeatures = SparseBackendFeatures.probe(ctx);
      expectEq("capabilities_backend", caps.backend, Arch.Cpu);
      expectEq("capabilities_stream_available", caps.streams.available, true);
      expectEq("capabilities_stream_events", caps.streams.events, ctx.supportsStreamEvents());
      expectEq("capabilities_descriptor_max_version", caps.descriptor.maxVersion, 2);
      expectEq("capabilities_mesh_kernel_relations", caps.mesh.kernelRelations, false);
      expectEq("capabilities_quant_kernel_parameters", caps.quant.kernelParameters, false);
      expectEq("capabilities_profiler_kernel", caps.profiler.kernel, ctx.isExtensionEnabled(Extension.KernelProfiler));
      expectEq("capabilities_profiler_scoped", caps.profiler.scoped, ctx.isExtensionEnabled(Extension.ScopedProfiler));
      expectEq("capabilities_profiler_memory", caps.profiler.memory, ctx.isExtensionEnabled(Extension.MemoryProfiler));
      expectEq("capabilities_interop_zero_copy", caps.interop.zeroCopy, ctx.isExtensionEnabled(Extension.ZeroCopy));
      expectEq("capabilities_interop_external_pointer", caps.interop.externalPointerImport, ctx.isExtensionEnabled(Extension.ExternalPointerImport));
      expectEq("capabilities_interop_dlpack", caps.interop.dlpack, probeTensor.supportsDLPack());
      expectEq("capabilities_sparse_host_reference", caps.sparse.hostReference, sparseFeatures.hostReferenceBackend);
      expectEq("capabilities_sparse_native_backend", caps.sparse.nativeBackend, sparseFeatures.nativeSparseBackend);
      expectEq("capabilities_version_descriptor", caps.version.descriptorVersion, 2);
      expectEq("capabilities_version_package", caps.version.packageVersion, manifestVersion());
      expectEq("capabilities_runtime_warning_count", caps.runtimeConfigWarnings.length, ctx.optionWarnings().length);
      probeTensor.close();
      probeTensor = null;

      kernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
        out[0] = 1;
      }, {name: "phase2_named_kernel"});
      expectEq("kernel_named_option", kernel.kernelName(), "phase2_named_kernel");
      var info = Diagnostics.kernelInfo(kernel);
      expectEq("kernel_named_info", Reflect.field(info, "kernelName"), "phase2_named_kernel");
      kernel.close();
      kernel = null;

      ctx.close();
    } catch (e:Dynamic) {
      if (kernel != null) {
        try kernel.close() catch (_:Dynamic) {}
      }
      if (probeTensor != null) {
        try probeTensor.close() catch (_:Dynamic) {}
      }
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
