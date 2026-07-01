package quadrants.profiler;

import quadrants.Context;
import quadrants.Native;

class MemoryProfiler {
  static inline var UnavailableReason:String = "Quadrants HashLink native memory profiler is unavailable";

  public static function probe(context:Context):MemoryProfilerStatus {
    var handle = context.nativeHandle();
    if (Native.profiler_memory_available(handle) != 0) {
      return new MemoryProfilerStatus(ProfilerAvailability.Available,
        "",
        Native.profiler_memory_allocated_bytes(handle),
        Native.profiler_memory_snode_bytes(handle),
        Native.profiler_memory_ndarray_bytes(handle));
    }
    return new MemoryProfilerStatus(ProfilerAvailability.Unavailable, UnavailableReason);
  }

  public static function printInfo(context:Context):MemoryProfilerStatus {
    var status = probe(context);
    if (!status.isAvailable()) {
      return status;
    }
    Native.profiler_memory_print(context.nativeHandle());
    return status;
  }
}
