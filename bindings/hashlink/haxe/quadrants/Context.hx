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

  public function new(arch:Arch = Cpu, enableProfiler:Bool = false) {
    Native.ensureConfigured();
    this.arch = arch;
    handle = Native.context_create_configured(arch, enableProfiler ? 1 : 0);
    root = new FieldsBuilder(this);
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

  public function profiler():Profiler {
    return new Profiler(this);
  }

  public function supportsStreamEvents():Bool {
    return Native.stream_supports_events(nativeHandle()) != 0;
  }

  public function setOfflineCache(enabled:Bool, path:String = ""):Void {
    var cachePath = @:privateAccess path.toUtf8();
    Native.context_set_offline_cache(nativeHandle(), enabled ? 1 : 0, cachePath);
    offlineCacheEnabled = enabled;
    offlineCachePath = path;
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
  }

  public function setRandomSeed(seed:Int):Void {
    Native.context_set_random_seed(nativeHandle(), seed);
  }

  public function setCpuMaxNumThreads(threadCount:Int):Void {
    if (threadCount <= 0) {
      throw "Quadrants CPU max thread count must be positive";
    }
    Native.context_set_cpu_max_num_threads(nativeHandle(), threadCount);
  }

  public function setFastMath(enabled:Bool):Void {
    Native.context_set_fast_math(nativeHandle(), enabled ? 1 : 0);
  }

  public function setBoundsCheck(enabled:Bool):Void {
    Native.context_set_bounds_check(nativeHandle(), enabled ? 1 : 0);
  }

  public function setDebugDump(path:String, printIr:Bool = true, printPreprocessedIr:Bool = false, printIrDebugInfo:Bool = false):Void {
    var dumpPath = @:privateAccess path.toUtf8();
    Native.context_set_debug_dump(nativeHandle(), dumpPath, printIr ? 1 : 0, printPreprocessedIr ? 1 : 0, printIrDebugInfo ? 1 : 0);
  }

  public function close():Void {
    if (!closed) {
      Native.context_close(handle);
      closed = true;
    }
  }
}
