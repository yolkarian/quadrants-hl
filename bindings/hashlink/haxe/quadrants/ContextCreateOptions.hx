package quadrants;

import quadrants.Types.Arch;
import quadrants.ContextOptions.AdOptions;
import quadrants.ContextOptions.CompileOptions;
import quadrants.ContextOptions.DebugOptions;
import quadrants.ContextOptions.MemoryOptions;
import quadrants.ContextOptions.OfflineCacheOptions;

typedef ContextCreateOptions = {
  @:optional var arch:Arch;
  @:optional var profiler:Bool;
  @:optional var fastMath:Bool;
  @:optional var boundsCheck:Bool;
  @:optional var randomSeed:Int;
  @:optional var cpuMaxNumThreads:Int;
  @:optional var offlineCache:OfflineCacheOptions;
  @:optional var compile:CompileOptions;
  @:optional var debug:DebugOptions;
  @:optional var ad:AdOptions;
  @:optional var memory:MemoryOptions;
}
