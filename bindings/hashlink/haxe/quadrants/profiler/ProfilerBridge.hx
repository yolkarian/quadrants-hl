package quadrants.profiler;

import quadrants.Context;
import quadrants.Native;

typedef ProfilerFeatureSet = {
  var enabled:Bool;
  var scoped:Bool;
  var memory:Bool;
  var kernel:Bool;
}

class ProfilerBridge {
  public static function features(context:Context):ProfilerFeatureSet {
    var handle = context.nativeHandle();
    return {
      enabled: Native.profiler_is_enabled(handle) != 0,
      scoped: Native.profiler_scoped_available(handle) != 0,
      memory: Native.profiler_memory_available(handle) != 0,
      kernel: Native.profiler_kernel_available(handle) != 0,
    };
  }

  public static function isEnabled(context:Context):Bool {
    return Native.profiler_is_enabled(context.nativeHandle()) != 0;
  }
}
