package quadrants;

typedef ProfilerRecord = {
  var count:Int;
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

  public function totalTime():Float {
    return Native.profiler_total_time(context.nativeHandle());
  }

  public function count(kernelName:String):Int {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    return Native.profiler_query_count(context.nativeHandle(), nameBytes);
  }

  public function avg(kernelName:String):Float {
    var nameBytes = @:privateAccess kernelName.toUtf8();
    return Native.profiler_query_avg(context.nativeHandle(), nameBytes);
  }

  public function record(kernelName:String):ProfilerRecord {
    return {count: count(kernelName), averageTime: avg(kernelName)};
  }
}
