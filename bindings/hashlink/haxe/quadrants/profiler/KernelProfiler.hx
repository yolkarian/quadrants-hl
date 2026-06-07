package quadrants.profiler;

import quadrants.Context;

class KernelProfiler {
  public static inline function clear(context:Context):Void {
    context.profiler().clear();
  }

  public static inline function clearInfo(context:Context):Void {
    context.profiler().clear();
  }

  public static inline function printInfo(context:Context, mode:ProfilerPrintMode = Count):Void {
    context.profiler().printInfo(mode);
  }

  public static inline function setToolkit(context:Context, toolkit:ProfilerToolkit):Bool {
    return context.profiler().setToolkit(toolkit);
  }

  public static inline function setMetricPreset(context:Context, preset:CuptiMetricPreset):Bool {
    return context.profiler().setMetricPreset(preset);
  }
}
