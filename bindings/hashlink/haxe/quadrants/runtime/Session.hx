package quadrants.runtime;

import quadrants.Context;
import quadrants.Profiler;
import quadrants.Stream;
import quadrants.Types.Arch;

class Session {
  final contextHandle:Context;
  var valid:Bool = true;

  public function new(arch:Arch = Cpu, enableProfiler:Bool = false) {
    contextHandle = new Context(arch, enableProfiler);
  }

  public function context():Context {
    return requireValid();
  }

  public function sync():Void {
    requireValid().sync();
  }

  public function stream():Stream {
    return requireValid().stream();
  }

  public function profiler():Profiler {
    return requireValid().profiler();
  }

  public function close():Void {
    if (valid) {
      contextHandle.close();
      valid = false;
    }
  }

  function requireValid():Context {
    if (!valid) {
      throw "Quadrants runtime session is invalid; create a new Session or call Runtime.init(...) again";
    }
    return contextHandle;
  }
}
