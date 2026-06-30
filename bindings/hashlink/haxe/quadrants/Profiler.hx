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

typedef KernelProfilerStats = {
  var count:Int;
  var avgMs:Float;
  var minMs:Float;
  var maxMs:Float;
}

class Profiler {
  final context:Context;
  final events:Array<Dynamic> = [];
  final activeNames:Array<String> = [];
  final activeStarts:Array<Float> = [];

  public function new(context:Context) {
    this.context = context;
  }

  public static function withScope(context:Context, name:String, body:Void->Void):Void {
    if (context == null) {
      throw "Quadrants Profiler.withScope requires a Context";
    }
    if (body == null) {
      throw "Quadrants Profiler.withScope requires a body";
    }
    var profiler = context.profiler();
    profiler.start(name);
    try {
      body();
    } catch (e:Dynamic) {
      profiler.stop();
      throw e;
    }
    profiler.stop();
  }

  public function start(kernelName:String):Void {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    activeNames.push(kernelName);
    activeStarts.push(haxe.Timer.stamp());
    Native.profiler_start(context.nativeHandle(), nameBytes);
  }

  public function stop():Void {
    Native.profiler_stop(context.nativeHandle());
    var end = haxe.Timer.stamp();
    if (activeNames.length > 0) {
      var name = activeNames.pop();
      var begin = activeStarts.pop();
      events.push({name: name, beginSeconds: begin, endSeconds: end, durationMs: (end - begin) * 1000.0});
    }
  }

  public function clear():Void {
    Native.profiler_clear(context.nativeHandle());
    events.resize(0);
    activeNames.resize(0);
    activeStarts.resize(0);
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

  public function kernel(kernelName:String):KernelProfilerStats {
    return {
      count: count(kernelName),
      avgMs: avg(kernelName),
      minMs: min(kernelName),
      maxMs: max(kernelName),
    };
  }

  public function traceEvents():Array<Dynamic> {
    return [for (event in events) Reflect.copy(event)];
  }

  public function memoryStats():Dynamic {
    if (!quadrants.profiler.ProfilerBridge.features(context).memory) {
      throw "Quadrants memory profiler capability is not available for this backend";
    }
    var status = quadrants.profiler.MemoryProfiler.probe(context);
    return {available: status.isAvailable(), reason: status.reason};
  }

  public function printMemory():Void {
    if (!quadrants.profiler.ProfilerBridge.features(context).memory) {
      throw "Quadrants memory profiler capability is not available for this backend";
    }
    var status = quadrants.profiler.MemoryProfiler.printInfo(context);
    if (!status.isAvailable()) {
      throw status.reason;
    }
  }
}
