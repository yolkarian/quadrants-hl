package quadrants.profiler;

import quadrants.Context;
import quadrants.Profiler;

class ScopedProfiler {
  final profiler:Profiler;
  var active:Bool = false;

  public function new(context:Context, name:String) {
    profiler = context.profiler();
    profiler.start(name);
    active = true;
  }

  public function close():Void {
    if (active) {
      profiler.stop();
      active = false;
    }
  }

  public static function run<T>(context:Context, name:String, body:Void->T):T {
    var scope = new ScopedProfiler(context, name);
    try {
      var result = body();
      scope.close();
      return result;
    } catch (e:Dynamic) {
      scope.close();
      throw e;
    }
  }
}
