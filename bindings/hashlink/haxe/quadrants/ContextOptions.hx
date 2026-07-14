package quadrants;

import haxe.Int64;
import quadrants.Types.Arch;

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
  public var compileCfgOptimization:Null<Bool> = null;
  public var compileNumThreads:Null<Int> = null;
  public var compileOptLevel:Null<OptLevel> = null;
  public var compileExternalOptLevel:Null<OptLevel> = null;
  public var deviceMemoryFraction:Null<Float> = null;
  public var cudaStackLimitBytes:Null<Int> = null;

  public function new(profilerEnabled:Bool = false) {
    this.profilerEnabled = profilerEnabled;
  }

  @:noCompletion public static function create():ContextOptions {
    return new ContextOptions();
  }

  @:noCompletion public static function fromCreateOptions(config:ContextCreateOptions):ContextOptions {
    var options = new ContextOptions(config != null && config.profiler == true);
    if (config == null) {
      return options;
    }
    options.arch = config.arch;
    options.fastMathEnabled = config.fastMath;
    options.boundsCheckEnabled = config.boundsCheck;
    options.randomSeed = config.randomSeed;
    if (config.cpuMaxNumThreads != null) {
      requirePositive(config.cpuMaxNumThreads, "Quadrants CPU max thread count must be positive");
      options.cpuMaxNumThreads = config.cpuMaxNumThreads;
    }
    if (config.offlineCache != null) {
      applyOfflineCache(options, config.offlineCache);
    }
    if (config.compile != null) {
      applyCompile(options, config.compile);
    }
    if (config.debug != null) {
      applyDebug(options, config.debug);
    }
    if (config.ad != null) {
      applyAd(options, config.ad);
    }
    if (config.memory != null) {
      applyMemory(options, config.memory);
    }
    return options;
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
    clone.compileCfgOptimization = compileCfgOptimization;
    clone.compileNumThreads = compileNumThreads;
    clone.compileOptLevel = compileOptLevel;
    clone.compileExternalOptLevel = compileExternalOptLevel;
    clone.deviceMemoryFraction = deviceMemoryFraction;
    clone.cudaStackLimitBytes = cudaStackLimitBytes;
    return clone;
  }

  public function applyTo(context:Context):Void {
    if (offlineCacheEnabled != null) {
      context.setOfflineCache(offlineCacheEnabled == true, offlineCachePath);
    }
    if (offlineCacheCleanPolicy != null) {
      context.setOfflineCachePolicy(offlineCacheCleanPolicy);
    }
    if (offlineCacheMaxSizeBytes != null) {
      context.setOfflineCacheMaxSizeBytes(offlineCacheMaxSizeBytes);
    }
    if (offlineCacheCleanFactor != null) {
      context.setOfflineCacheCleanFactor(offlineCacheCleanFactor);
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
      context.setDebugMode(debugLaunchEnabled == true);
    }
    if (debugTimelineEnabled != null) {
      context.setTimeline(debugTimelineEnabled == true);
    }
    if (compileCfgOptimization != null) {
      context.setCfgOptimization(compileCfgOptimization == true);
    }
    if (compileOptLevel != null) {
      context.setOptLevel(compileOptLevel);
    }
    if (compileExternalOptLevel != null) {
      context.setExternalOptLevel(compileExternalOptLevel);
    }
  }

  static function applyOfflineCache(options:ContextOptions, config:OfflineCacheOptions):Void {
    options.offlineCacheEnabled = config.enabled;
    options.offlineCachePath = config.path == null ? "" : config.path;
    options.offlineCacheCleanPolicy = config.cleanPolicy;
    if (config.maxSizeBytes != null) {
      requirePositiveInt64(config.maxSizeBytes, "Quadrants offline cache max size must be positive");
      options.offlineCacheMaxSizeBytes = config.maxSizeBytes;
    }
    if (config.cleanFactor != null) {
      requirePositiveFloat(config.cleanFactor, "Quadrants offline cache clean factor must be positive");
      options.offlineCacheCleanFactor = config.cleanFactor;
    }
  }

  static function applyCompile(options:ContextOptions, config:CompileOptions):Void {
    options.compileCfgOptimization = config.cfgOptimization;
    var compileThreads = config.numThreads != null ? config.numThreads : config.numCompileThreads;
    if (compileThreads != null) {
      requirePositive(compileThreads, "Quadrants numThreads must be positive");
    }
    options.compileNumThreads = compileThreads;
    options.compileOptLevel = config.optLevel;
    options.compileExternalOptLevel = config.externalOptLevel;
  }

  static function applyDebug(options:ContextOptions, config:DebugOptions):Void {
    if (config.path != null) {
      options.debugDumpPath = config.path;
      options.debugDumpPrintIr = config.printIr != false;
      options.debugDumpPrintPreprocessedIr = config.printPreprocessedIr == true;
      options.debugDumpPrintIrDebugInfo = config.printIrDebugInfo == true;
    }
    options.debugLaunchEnabled = config.launchDebug;
    options.debugTimelineEnabled = config.timeline;
  }

  static function applyAd(options:ContextOptions, config:AdOptions):Void {
    var stackSize = config.stackSize == null ? 0 : config.stackSize;
    var threshold = config.sparseThresholdBytes == null ? 104857600 : config.sparseThresholdBytes;
    requireNonNegative(stackSize, "Quadrants adstack size must be non-negative");
    requireNonNegative(threshold, "Quadrants adstack sparse threshold must be non-negative");
    options.adstackExperimentalEnabled = config.experimental == true;
    options.adstackSize = stackSize;
    options.adstackSparseThresholdBytes = threshold;
  }

  static function applyMemory(options:ContextOptions, config:MemoryOptions):Void {
    if (config.deviceMemoryFraction != null) {
      requireMemoryFraction(config.deviceMemoryFraction);
      options.deviceMemoryFraction = config.deviceMemoryFraction;
    }
    if (config.cudaStackLimitBytes != null) {
      requireNonNegative(config.cudaStackLimitBytes, "Quadrants cuda stack limit must be non-negative");
      options.cudaStackLimitBytes = config.cudaStackLimitBytes;
    }
  }

  static function requirePositive(value:Int, message:String):Void {
    if (value <= 0) {
      throw message;
    }
  }

  static function requireNonNegative(value:Int, message:String):Void {
    if (value < 0) {
      throw message;
    }
  }

  static function requireMemoryFraction(value:Float):Void {
    if (!(value > 0.0 && value <= 1.0)) {
      throw "Quadrants device memory fraction must be in (0, 1]";
    }
  }

  static function requirePositiveInt64(value:Int64, message:String):Void {
    if (Int64.compare(value, Int64.make(0, 0)) <= 0) {
      throw message;
    }
  }

  static function requirePositiveFloat(value:Float, message:String):Void {
    if (!(value > 0.0)) {
      throw message;
    }
  }
}
