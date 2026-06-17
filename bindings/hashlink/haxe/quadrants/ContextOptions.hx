package quadrants;

import haxe.Int64;
import quadrants.Types.Arch;
import quadrants.Types.DType;

typedef OfflineCacheOptions = {
  var enabled:Bool;
  @:optional var path:String;
  @:optional var cleanPolicy:CacheCleanPolicy;
  @:optional var maxSizeBytes:Int64;
  @:optional var cleanFactor:Float;
}

typedef CompileOptions = {
  @:optional var cfgOptimization:Bool;
  @:optional var numThreads:Int;
  @:optional var numCompileThreads:Int;
  @:optional var optLevel:OptLevel;
  @:optional var externalOptLevel:OptLevel;
}

typedef DefaultDTypeOptions = {
  @:optional var fp:DType;
  @:optional var ip:DType;
  @:optional var up:DType;
}

typedef MemoryOptions = {
  @:optional var deviceMemoryFraction:Float;
  @:optional var cudaStackLimitBytes:Int;
}

typedef AdOptions = {
  @:optional var experimental:Bool;
  @:optional var stackSize:Int;
  @:optional var sparseThresholdBytes:Int;
}

typedef DebugOptions = {
  @:optional var path:String;
  @:optional var printIr:Bool;
  @:optional var printPreprocessedIr:Bool;
  @:optional var printIrDebugInfo:Bool;
  @:optional var launchDebug:Bool;
  @:optional var timeline:Bool;
}


@:final class ContextOptions {
  public var arch:Null<Arch> = null;
  public var profilerEnabled:Bool;
  public var offlineCacheEnabled:Null<Bool> = null;
  public var offlineCachePath:String = "";
  public var offlineCacheCleanPolicy:Null<CacheCleanPolicy> = null;
  public var offlineCacheMaxSizeBytes:Null<Int64> = null;
  public var offlineCacheCleanFactor:Null<Float> = null;
  public var adstackExperimentalEnabled:Null<Bool> = null;
  public var adstackSize:Int = 0;
  public var adstackSparseThresholdBytes:Int = 104857600;
  public var randomSeed:Null<Int> = null;
  public var cpuMaxNumThreads:Null<Int> = null;
  public var fastMathEnabled:Null<Bool> = null;
  public var boundsCheckEnabled:Null<Bool> = null;
  public var debugDumpPath:Null<String> = null;
  public var debugDumpPrintIr:Bool = true;
  public var debugDumpPrintPreprocessedIr:Bool = false;
  public var debugDumpPrintIrDebugInfo:Bool = false;
  public var debugLaunchEnabled:Null<Bool> = null;
  public var debugTimelineEnabled:Null<Bool> = null;
  public var warnOnFieldMirrorFallbackEnabled:Null<Bool> = null;
  public var compileCfgOptimization:Null<Bool> = null;
  public var compileNumThreads:Null<Int> = null;
  public var compileOptLevel:Null<OptLevel> = null;
  public var compileExternalOptLevel:Null<OptLevel> = null;
  public var defaultFpDType:Null<DType> = null;
  public var defaultIpDType:Null<DType> = null;
  public var defaultUpDType:Null<DType> = null;
  public var deviceMemoryFraction:Null<Float> = null;
  public var cudaStackLimitBytes:Null<Int> = null;

  public function new(profilerEnabled:Bool = false) {
    this.profilerEnabled = profilerEnabled;
  }

  public static function create():ContextOptions {
    return new ContextOptions();
  }

  public static function builder():ContextOptionsBuilder {
    return new ContextOptionsBuilder();
  }

  public static function fromCreateOptions(config:ContextCreateOptions):ContextOptions {
    var builder = ContextOptions.builder();
    if (config == null) {
      return builder.build();
    }
    if (config.arch != null) {
      builder.arch(config.arch);
    }
    if (config.profiler != null) {
      builder.profiler(config.profiler == true);
    }
    if (config.fastMath != null) {
      builder.fastMath(config.fastMath == true);
    }
    if (config.boundsCheck != null) {
      builder.boundsCheck(config.boundsCheck == true);
    }
    if (config.randomSeed != null) {
      builder.randomSeed(config.randomSeed);
    }
    if (config.cpuMaxNumThreads != null) {
      builder.cpuMaxNumThreads(config.cpuMaxNumThreads);
    }
    if (config.offlineCache != null) {
      builder.offlineCache(config.offlineCache);
    }
    if (config.compile != null) {
      builder.compile(config.compile);
    }
    if (config.debug != null) {
      builder.debug(config.debug);
    }
    if (config.ad != null) {
      builder.ad(config.ad);
    }
    if (config.memory != null) {
      builder.memory(config.memory);
    }
    return builder.build();
  }

  public static function withKernelProfiler(enabled:Bool = true):ContextOptions {
    return new ContextOptions(enabled);
  }

  public function copy():ContextOptions {
    var clone = new ContextOptions(profilerEnabled);
    clone.arch = arch;
    clone.offlineCacheEnabled = offlineCacheEnabled;
    clone.offlineCachePath = offlineCachePath;
    clone.offlineCacheCleanPolicy = offlineCacheCleanPolicy;
    clone.offlineCacheMaxSizeBytes = offlineCacheMaxSizeBytes;
    clone.offlineCacheCleanFactor = offlineCacheCleanFactor;
    clone.adstackExperimentalEnabled = adstackExperimentalEnabled;
    clone.adstackSize = adstackSize;
    clone.adstackSparseThresholdBytes = adstackSparseThresholdBytes;
    clone.randomSeed = randomSeed;
    clone.cpuMaxNumThreads = cpuMaxNumThreads;
    clone.fastMathEnabled = fastMathEnabled;
    clone.boundsCheckEnabled = boundsCheckEnabled;
    clone.debugDumpPath = debugDumpPath;
    clone.debugDumpPrintIr = debugDumpPrintIr;
    clone.debugDumpPrintPreprocessedIr = debugDumpPrintPreprocessedIr;
    clone.debugDumpPrintIrDebugInfo = debugDumpPrintIrDebugInfo;
    clone.debugLaunchEnabled = debugLaunchEnabled;
    clone.debugTimelineEnabled = debugTimelineEnabled;
    clone.warnOnFieldMirrorFallbackEnabled = warnOnFieldMirrorFallbackEnabled;
    clone.compileCfgOptimization = compileCfgOptimization;
    clone.compileNumThreads = compileNumThreads;
    clone.compileOptLevel = compileOptLevel;
    clone.compileExternalOptLevel = compileExternalOptLevel;
    clone.defaultFpDType = defaultFpDType;
    clone.defaultIpDType = defaultIpDType;
    clone.defaultUpDType = defaultUpDType;
    clone.deviceMemoryFraction = deviceMemoryFraction;
    clone.cudaStackLimitBytes = cudaStackLimitBytes;
    return clone;
  }

  public function withArch(arch:Arch):ContextOptions {
    this.arch = arch;
    return this;
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
    requireNonNegative(stackSize, "Quadrants adstack size must be non-negative");
    requireNonNegative(sparseThresholdBytes, "Quadrants adstack sparse threshold must be non-negative");
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

  public function warnOnFieldMirrorFallback(enabled:Bool = true):ContextOptions {
    warnOnFieldMirrorFallbackEnabled = enabled;
    return this;
  }

  public function applyTo(context:Context):Void {
    if (offlineCacheEnabled != null) {
      context.setOfflineCache(offlineCacheEnabled == true, offlineCachePath);
    }
    if (offlineCacheCleanPolicy != null) {
      context.recordOptionWarning('ContextOptions.offlineCache.cleanPolicy=${offlineCacheCleanPolicy} is parsed but not yet applied by the HashLink bridge');
    }
    if (offlineCacheMaxSizeBytes != null) {
      context.recordOptionWarning('ContextOptions.offlineCache.maxSizeBytes=${offlineCacheMaxSizeBytes} is parsed but not yet applied by the HashLink bridge');
    }
    if (offlineCacheCleanFactor != null) {
      context.recordOptionWarning('ContextOptions.offlineCache.cleanFactor=${offlineCacheCleanFactor} is parsed but not yet applied by the HashLink bridge');
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
    if (debugLaunchEnabled != null) {
      context.recordOptionWarning('ContextOptions.debug.launchDebug=${debugLaunchEnabled} is parsed but not yet applied by the HashLink bridge');
    }
    if (debugTimelineEnabled != null) {
      context.recordOptionWarning('ContextOptions.debug.timeline=${debugTimelineEnabled} is parsed but not yet applied by the HashLink bridge');
    }
    if (warnOnFieldMirrorFallbackEnabled != null) {
      context.setWarnOnFieldMirrorFallback(warnOnFieldMirrorFallbackEnabled == true);
    }
    if (compileCfgOptimization != null) {
      context.recordOptionWarning('ContextOptions.compile.cfgOptimization=${compileCfgOptimization} is parsed but not yet applied by the HashLink bridge');
    }
    if (compileNumThreads != null) {
      context.recordOptionWarning('ContextOptions.compile.numCompileThreads=${compileNumThreads} is parsed but not yet applied by the HashLink bridge');
    }
    if (compileOptLevel != null) {
      context.recordOptionWarning('ContextOptions.compile.optLevel=${compileOptLevel} is parsed but not yet applied by the HashLink bridge');
    }
    if (compileExternalOptLevel != null) {
      context.recordOptionWarning('ContextOptions.compile.externalOptLevel=${compileExternalOptLevel} is parsed but not yet applied by the HashLink bridge');
    }
    if (defaultFpDType != null || defaultIpDType != null || defaultUpDType != null) {
      context.recordOptionWarning('ContextOptions.defaults are parsed but not yet applied by the HashLink bridge');
    }
    if (deviceMemoryFraction != null) {
      context.recordOptionWarning('ContextOptions.memory.deviceMemoryFraction=${deviceMemoryFraction} is parsed but not yet applied by the HashLink bridge');
    }
    if (cudaStackLimitBytes != null) {
      context.recordOptionWarning('ContextOptions.memory.cudaStackLimitBytes=${cudaStackLimitBytes} is parsed but not yet applied by the HashLink bridge');
    }
  }

  public static function requireNonNegative(value:Int, message:String):Void {
    if (value < 0) {
      throw message;
    }
  }

  public static function requireMemoryFraction(value:Float):Void {
    if (!(value > 0.0 && value <= 1.0)) {
      throw "Quadrants device memory fraction must be in (0, 1]";
    }
  }

  public static function requirePositiveInt64(value:Int64, message:String):Void {
    if (Int64.compare(value, Int64.make(0, 0)) <= 0) {
      throw message;
    }
  }

  public static function requirePositiveFloat(value:Float, message:String):Void {
    if (!(value > 0.0)) {
      throw message;
    }
  }
}

class ContextOptionsBuilder {
  final options:ContextOptions;

  public function new() {
    options = ContextOptions.create();
  }

  public function arch(arch:Arch):ContextOptionsBuilder {
    options.withArch(arch);
    return this;
  }

  public function profiler(enabled:Bool = true):ContextOptionsBuilder {
    options.withProfiler(enabled);
    return this;
  }

  public function fastMath(enabled:Bool):ContextOptionsBuilder {
    options.withFastMath(enabled);
    return this;
  }

  public function boundsCheck(enabled:Bool):ContextOptionsBuilder {
    options.withBoundsCheck(enabled);
    return this;
  }

  public function randomSeed(seed:Int):ContextOptionsBuilder {
    options.withRandomSeed(seed);
    return this;
  }

  public function cpuMaxNumThreads(threadCount:Int):ContextOptionsBuilder {
    options.withCpuMaxNumThreads(threadCount);
    return this;
  }

  public function offlineCache(config:OfflineCacheOptions):ContextOptionsBuilder {
    if (config == null) {
      throw "Quadrants ContextOptions.builder().offlineCache requires a config object";
    }
    options.withOfflineCache(config.enabled, config.path == null ? "" : config.path);
    options.offlineCacheCleanPolicy = config.cleanPolicy;
    if (config.maxSizeBytes != null) {
      ContextOptions.requirePositiveInt64(config.maxSizeBytes, "Quadrants offline cache max size must be positive");
      options.offlineCacheMaxSizeBytes = config.maxSizeBytes;
    }
    if (config.cleanFactor != null) {
      ContextOptions.requirePositiveFloat(config.cleanFactor, "Quadrants offline cache clean factor must be positive");
      options.offlineCacheCleanFactor = config.cleanFactor;
    }
    return this;
  }

  public function compile(config:CompileOptions):ContextOptionsBuilder {
    if (config == null) {
      throw "Quadrants ContextOptions.builder().compile requires a config object";
    }
    options.compileCfgOptimization = config.cfgOptimization;
    var compileThreads = config.numThreads != null ? config.numThreads : config.numCompileThreads;
    if (compileThreads != null && compileThreads <= 0) {
      throw "Quadrants numThreads must be positive";
    }
    options.compileNumThreads = compileThreads;
    options.compileOptLevel = config.optLevel;
    options.compileExternalOptLevel = config.externalOptLevel;
    return this;
  }

  public function defaults(config:DefaultDTypeOptions):ContextOptionsBuilder {
    if (config == null) {
      throw "Quadrants ContextOptions.builder().defaults requires a config object";
    }
    options.defaultFpDType = config.fp;
    options.defaultIpDType = config.ip;
    options.defaultUpDType = config.up;
    return this;
  }

  public function memory(config:MemoryOptions):ContextOptionsBuilder {
    if (config == null) {
      throw "Quadrants ContextOptions.builder().memory requires a config object";
    }
    if (config.deviceMemoryFraction != null) {
      ContextOptions.requireMemoryFraction(config.deviceMemoryFraction);
      options.deviceMemoryFraction = config.deviceMemoryFraction;
    }
    if (config.cudaStackLimitBytes != null) {
      ContextOptions.requireNonNegative(config.cudaStackLimitBytes, "Quadrants cuda stack limit must be non-negative");
      options.cudaStackLimitBytes = config.cudaStackLimitBytes;
    }
    return this;
  }

  public function ad(config:AdOptions):ContextOptionsBuilder {
    if (config == null) {
      throw "Quadrants ContextOptions.builder().ad requires a config object";
    }
    options.withAdstackConfig(config.experimental == true, config.stackSize == null ? 0 : config.stackSize,
      config.sparseThresholdBytes == null ? 104857600 : config.sparseThresholdBytes);
    return this;
  }

  public function debug(config:DebugOptions):ContextOptionsBuilder {
    if (config == null) {
      throw "Quadrants ContextOptions.builder().debug requires a config object";
    }
    if (config.path != null) {
      options.withDebugDump(config.path,
        config.printIr != false,
        config.printPreprocessedIr == true,
        config.printIrDebugInfo == true);
    }
    options.debugLaunchEnabled = config.launchDebug;
    options.debugTimelineEnabled = config.timeline;
    return this;
  }

  public function warnOnFieldMirrorFallback(enabled:Bool = true):ContextOptionsBuilder {
    options.warnOnFieldMirrorFallback(enabled);
    return this;
  }

  public function build():ContextOptions {
    return options.copy();
  }
}
