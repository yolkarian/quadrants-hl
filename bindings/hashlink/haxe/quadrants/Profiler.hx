package quadrants;

import quadrants.profiler.CuptiMetric;
import quadrants.profiler.CuptiMetricPreset;
import quadrants.profiler.ProfilerPrintMode;
import quadrants.profiler.ProfilerToolkit;

typedef ProfilerRecord = {
  var count:Int;
  var minTime:Float;
  var maxTime:Float;
  var averageTime:Float;
}

class Profiler {
  final context:Context;

  public function new(context:Context) {
    this.context = context;
  }

  public function start(kernelName:String):Void {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    Native.profiler_start(context.nativeHandle(), nameBytes);
  }

  public function stop():Void {
    Native.profiler_stop(context.nativeHandle());
  }

  public function clear():Void {
    Native.profiler_clear(context.nativeHandle());
  }

  public function clearInfo():Void {
    clear();
  }

  public function printInfo(mode:ProfilerPrintMode = Count):Void {
    switch (mode) {
      case Count:
        Sys.println('Quadrants kernel profiler total time: ${totalTime()} s');
      case Trace:
        Sys.println('Quadrants HashLink profiler trace listing is unavailable; use record(...), count(...), min(...), max(...), and avg(...) for named kernels.');
        Sys.println('Quadrants kernel profiler total time: ${totalTime()} s');
      default:
        Sys.println('Quadrants kernel profiler total time: ${totalTime()} s');
    }
  }

  public function setToolkit(toolkit:ProfilerToolkit):Bool {
    var nameBytes = @:privateAccess toolkit.nativeName().toUtf8();
    return Native.profiler_set_toolkit(context.nativeHandle(), nameBytes) != 0;
  }

  public function setMetrics(metrics:Array<CuptiMetric>):Bool {
    if (metrics == null || metrics.length == 0) {
      throw "Quadrants profiler metrics must not be empty";
    }
    var names = new hl.NativeArray<hl.Bytes>(metrics.length);
    for (i in 0...metrics.length) {
      names[i] = @:privateAccess metrics[i].nativeName().toUtf8();
    }
    clear();
    return Native.profiler_set_metrics(context.nativeHandle(), names) != 0;
  }

  public function setMetricPreset(preset:CuptiMetricPreset):Bool {
    return setMetrics(CuptiMetric.preset(preset));
  }

  public function totalTime():Float {
    return Native.profiler_total_time(context.nativeHandle());
  }

  public function count(kernelName:String):Int {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    return Native.profiler_query_count(context.nativeHandle(), nameBytes);
  }

  public function min(kernelName:String):Float {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    return Native.profiler_query_min(context.nativeHandle(), nameBytes);
  }

  public function max(kernelName:String):Float {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    return Native.profiler_query_max(context.nativeHandle(), nameBytes);
  }

  public function avg(kernelName:String):Float {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    return Native.profiler_query_avg(context.nativeHandle(), nameBytes);
  }

  public function record(kernelName:String):ProfilerRecord {
    return {count: count(kernelName), minTime: min(kernelName), maxTime: max(kernelName), averageTime: avg(kernelName)};
  }

  public function recordKernel(kernel:Kernel):ProfilerRecord {
    return record(kernel.kernelName());
  }
}
