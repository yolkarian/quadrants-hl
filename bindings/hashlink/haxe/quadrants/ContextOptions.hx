package quadrants;

@:final class ContextOptions {
  public var profilerEnabled(default, null):Bool;
  public var offlineCacheEnabled(default, null):Null<Bool> = null;
  public var offlineCachePath(default, null):String = "";
  public var adstackExperimentalEnabled(default, null):Null<Bool> = null;
  public var adstackSize(default, null):Int = 0;
  public var adstackSparseThresholdBytes(default, null):Int = 104857600;
  public var randomSeed(default, null):Null<Int> = null;
  public var cpuMaxNumThreads(default, null):Null<Int> = null;
  public var fastMathEnabled(default, null):Null<Bool> = null;
  public var boundsCheckEnabled(default, null):Null<Bool> = null;
  public var debugDumpPath(default, null):Null<String> = null;
  public var debugDumpPrintIr(default, null):Bool = true;
  public var debugDumpPrintPreprocessedIr(default, null):Bool = false;
  public var debugDumpPrintIrDebugInfo(default, null):Bool = false;

  public function new(profilerEnabled:Bool = false) {
    this.profilerEnabled = profilerEnabled;
  }

  public static function create():ContextOptions {
    return new ContextOptions();
  }

  public static function withKernelProfiler(enabled:Bool = true):ContextOptions {
    return new ContextOptions(enabled);
  }

  public function withProfiler(enabled:Bool = true):ContextOptions {
    profilerEnabled = enabled;
    return this;
  }

  public function withOfflineCache(enabled:Bool, path:String = ""):ContextOptions {
    offlineCacheEnabled = enabled;
    offlineCachePath = path;
    return this;
  }

  public function withAdstackConfig(experimentalEnabled:Bool, stackSize:Int = 0, sparseThresholdBytes:Int = 104857600):ContextOptions {
    if (stackSize < 0) {
      throw "Quadrants adstack size must be non-negative";
    }
    if (sparseThresholdBytes < 0) {
      throw "Quadrants adstack sparse threshold must be non-negative";
    }
    adstackExperimentalEnabled = experimentalEnabled;
    adstackSize = stackSize;
    adstackSparseThresholdBytes = sparseThresholdBytes;
    return this;
  }

  public function withRandomSeed(seed:Int):ContextOptions {
    randomSeed = seed;
    return this;
  }

  public function withCpuMaxNumThreads(threadCount:Int):ContextOptions {
    if (threadCount <= 0) {
      throw "Quadrants CPU max thread count must be positive";
    }
    cpuMaxNumThreads = threadCount;
    return this;
  }

  public function withFastMath(enabled:Bool):ContextOptions {
    fastMathEnabled = enabled;
    return this;
  }

  public function withBoundsCheck(enabled:Bool):ContextOptions {
    boundsCheckEnabled = enabled;
    return this;
  }

  public function withDebugDump(path:String, printIr:Bool = true, printPreprocessedIr:Bool = false, printIrDebugInfo:Bool = false):ContextOptions {
    debugDumpPath = path;
    debugDumpPrintIr = printIr;
    debugDumpPrintPreprocessedIr = printPreprocessedIr;
    debugDumpPrintIrDebugInfo = printIrDebugInfo;
    return this;
  }

  public function applyTo(context:Context):Void {
    if (offlineCacheEnabled != null) {
      context.setOfflineCache(offlineCacheEnabled == true, offlineCachePath);
    }
    if (adstackExperimentalEnabled != null) {
      context.setAdstackConfig(adstackExperimentalEnabled == true, adstackSize, adstackSparseThresholdBytes);
    }
    if (randomSeed != null) {
      context.setRandomSeed(cast randomSeed);
    }
    if (cpuMaxNumThreads != null) {
      context.setCpuMaxNumThreads(cast cpuMaxNumThreads);
    }
    if (fastMathEnabled != null) {
      context.setFastMath(fastMathEnabled == true);
    }
    if (boundsCheckEnabled != null) {
      context.setBoundsCheck(boundsCheckEnabled == true);
    }
    if (debugDumpPath != null) {
      context.setDebugDump(cast debugDumpPath, debugDumpPrintIr, debugDumpPrintPreprocessedIr, debugDumpPrintIrDebugInfo);
    }
  }
}
