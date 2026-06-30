package quadrants;

import quadrants.Types.Arch;
import quadrants.Native.QContext;
import sys.FileSystem;

class Context {
  final handle:QContext;
  public final arch:Arch;
  public final root:FieldsBuilder;
  public var offlineCacheEnabled(default, null):Bool = false;
  public var offlineCachePath(default, null):String = "";
  var closed:Bool = false;
  final optionWarningMessages:Array<String> = [];
  final configuredOptions:ContextOptions;
  var profilerInstance:Profiler = null;

  public function new(arch:Arch = Cpu, enableProfiler:Bool = false, options:ContextOptions = null) {
    Native.ensureConfigured();
    VersionInfo.checkNativeCompatibility();
    var selectedArch = options != null && options.arch != null ? cast options.arch : arch;
    this.arch = selectedArch;
    var profilerEnabled = enableProfiler;
    if (options != null && options.profilerEnabled) {
      profilerEnabled = true;
    }
    handle = Native.context_create_configured(selectedArch, profilerEnabled ? 1 : 0);
    root = new FieldsBuilder(this);
    configuredOptions = options == null ? ContextOptions.create() : options.copy();
    configuredOptions.arch = selectedArch;
    if (options != null) {
      options.applyTo(this);
    }
  }

  public static function create(?options:ContextCreateOptions):Context {
    var resolved = ContextOptions.fromCreateOptions(options);
    var selectedArch = resolved.arch == null ? Arch.Cpu : resolved.arch;
    return new Context(selectedArch, resolved.profilerEnabled, resolved);
  }

  public function currentOptions():ContextOptions {
    return configuredOptions.copy();
  }

  public function optionWarnings():Array<String> {
    return [for (warning in optionWarningMessages) warning];
  }

  public function clearOptionWarnings():Void {
    optionWarningMessages.resize(0);
  }

  public function recordOptionWarning(message:String):Void {
    optionWarningMessages.push(message);
  }

  public function capabilities():Capabilities {
    return new Capabilities(this);
  }

  public function nativeHandle():QContext {
    if (closed) {
      throw "Quadrants context is closed";
    }
    return handle;
  }

  public function sync():Void {
    Native.context_sync(nativeHandle());
  }

  public function stream():Stream {
    return new Stream(this);
  }

  public inline function createStream():Stream {
    return stream();
  }

  public function createEvent():StreamEvent {
    return new StreamEvent(this);
  }

  public function profiler():Profiler {
    if (profilerInstance == null) {
      profilerInstance = new Profiler(this);
    }
    return profilerInstance;
  }

  public function isExtensionEnabled(extension:Extension):Bool {
    return switch (extension) {
      case Extension.Cuda:
        arch == Arch.Cuda;
      case Extension.CudaGlInterop:
        Native.cuda_gl_interop_available(nativeHandle()) != 0;
      case Extension.StreamEvents:
        supportsStreamEvents();
      case Extension.KernelProfiler:
        Native.profiler_kernel_available(nativeHandle()) != 0;
      case Extension.ScopedProfiler:
        Native.profiler_scoped_available(nativeHandle()) != 0;
      case Extension.MemoryProfiler:
        Native.profiler_memory_available(nativeHandle()) != 0;
      case Extension.ZeroCopy:
        Native.ndarray_supports_zero_copy(nativeHandle()) != 0;
      case Extension.ExternalPointerImport:
        Native.ndarray_supports_external_pointer_import(nativeHandle()) != 0;
      default:
        false;
    };
  }

  public function supportsStreamEvents():Bool {
    return Native.stream_supports_events(nativeHandle()) != 0;
  }

  public function setOfflineCache(enabled:Bool, path:String = ""):Void {
    var cachePath = @:privateAccess path.toUtf8();
    Native.context_set_offline_cache(nativeHandle(), enabled ? 1 : 0, cachePath);
    offlineCacheEnabled = enabled;
    offlineCachePath = path;
    configuredOptions.offlineCacheEnabled = enabled;
    configuredOptions.offlineCachePath = path;
  }

  public function clearOfflineCache():Void {
    if (offlineCachePath == null || offlineCachePath.length == 0) {
      throw "Quadrants offline cache path is unknown; pass an explicit path to setOfflineCache() first";
    }
    if (!FileSystem.exists(offlineCachePath)) {
      return;
    }
    deleteTree(offlineCachePath);
  }

  static function deleteTree(path:String):Void {
    if (FileSystem.isDirectory(path)) {
      for (entry in FileSystem.readDirectory(path)) {
        deleteTree(path + "/" + entry);
      }
      FileSystem.deleteDirectory(path);
    } else {
      FileSystem.deleteFile(path);
    }
  }

  public function setAdstackConfig(experimentalEnabled:Bool, stackSize:Int = 0, sparseThresholdBytes:Int = 104857600):Void {
    if (stackSize < 0) {
      throw "Quadrants adstack size must be non-negative";
    }
    if (sparseThresholdBytes < 0) {
      throw "Quadrants adstack sparse threshold must be non-negative";
    }
    Native.context_set_adstack_config(nativeHandle(), experimentalEnabled ? 1 : 0, stackSize, sparseThresholdBytes);
    configuredOptions.adstackExperimentalEnabled = experimentalEnabled;
    configuredOptions.adstackSize = stackSize;
    configuredOptions.adstackSparseThresholdBytes = sparseThresholdBytes;
  }

  public function setRandomSeed(seed:Int):Void {
    Native.context_set_random_seed(nativeHandle(), seed);
    configuredOptions.randomSeed = seed;
  }

  public function setCpuMaxNumThreads(threadCount:Int):Void {
    if (threadCount <= 0) {
      throw "Quadrants CPU max thread count must be positive";
    }
    Native.context_set_cpu_max_num_threads(nativeHandle(), threadCount);
    configuredOptions.cpuMaxNumThreads = threadCount;
  }

  public function setFastMath(enabled:Bool):Void {
    Native.context_set_fast_math(nativeHandle(), enabled ? 1 : 0);
    configuredOptions.fastMathEnabled = enabled;
  }

  public function setBoundsCheck(enabled:Bool):Void {
    Native.context_set_bounds_check(nativeHandle(), enabled ? 1 : 0);
    configuredOptions.boundsCheckEnabled = enabled;
  }

  public function setDebugDump(path:String, printIr:Bool = true, printPreprocessedIr:Bool = false, printIrDebugInfo:Bool = false):Void {
    var dumpPath = @:privateAccess path.toUtf8();
    Native.context_set_debug_dump(nativeHandle(), dumpPath, printIr ? 1 : 0, printPreprocessedIr ? 1 : 0, printIrDebugInfo ? 1 : 0);
    configuredOptions.debugDumpPath = path;
    configuredOptions.debugDumpPrintIr = printIr;
    configuredOptions.debugDumpPrintPreprocessedIr = printPreprocessedIr;
    configuredOptions.debugDumpPrintIrDebugInfo = printIrDebugInfo;
  }

  public function close():Void {
    if (!closed) {
      Native.context_close(handle);
      closed = true;
    }
  }
}
