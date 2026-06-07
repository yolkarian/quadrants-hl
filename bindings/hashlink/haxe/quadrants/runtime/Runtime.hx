package quadrants.runtime;

import quadrants.Context;
import quadrants.ContextOptions;
import quadrants.Profiler;
import quadrants.Stream;
import quadrants.Types.Arch;

class Runtime {
  static var defaultSession:Session = null;

  public static function init(arch:Arch = Cpu, enableProfiler:Bool = false, options:ContextOptions = null):Session {
    reset();
    defaultSession = new Session(arch, enableProfiler, options);
    return defaultSession;
  }

  public static function reset():Void {
    if (defaultSession != null) {
      defaultSession.close();
      defaultSession = null;
    }
  }

  public static function session():Session {
    return requireSession();
  }

  public static function context():Context {
    return requireSession().context();
  }

  public static function sync():Void {
    requireSession().sync();
  }

  public static function stream():Stream {
    return requireSession().stream();
  }

  public static function profiler():Profiler {
    return requireSession().profiler();
  }

  static function requireSession():Session {
    if (defaultSession == null) {
      throw "Quadrants Runtime is not initialized; call Runtime.init(...) first";
    }
    return defaultSession;
  }
}
