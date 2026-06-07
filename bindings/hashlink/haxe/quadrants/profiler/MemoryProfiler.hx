package quadrants.profiler;

import quadrants.Context;
import quadrants.Native;

class MemoryProfiler {
  static inline var UnavailableReason:String = "Quadrants HashLink native memory profiler is unavailable";

  public static function probe(context:Context):MemoryProfilerStatus {
    if (Native.profiler_memory_available(context.nativeHandle()) != 0) {
      return new MemoryProfilerStatus(ProfilerAvailability.Available);
    }
    return new MemoryProfilerStatus(ProfilerAvailability.Unavailable, UnavailableReason);
  }

  public static function printInfo(context:Context):MemoryProfilerStatus {
    var status = probe(context);
    if (!status.isAvailable()) {
      return status;
    }
    return new MemoryProfilerStatus(ProfilerAvailability.Unavailable, "Quadrants HashLink memory profiler print binding is unavailable");
  }
}
