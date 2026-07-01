import quadrants.Context;
import quadrants.Stream;
import quadrants.runtime.Runtime;
import quadrants.runtime.Session;

class TestRuntimeFacade {
  static function expectThrows(name:String, contains:String, f:Void->Void):Void {
    try {
      f();
    } catch (e:Dynamic) {
      var message = Std.string(e);
      if (message.indexOf(contains) < 0) {
        throw '${name}: expected error containing "${contains}", got "${message}"';
      }
      return;
    }
    throw '${name}: expected an error containing "${contains}"';
  }

  public static function run():Void {
    TestRuntimeSupport.closeSharedContexts();
    Runtime.reset();
    expectThrows("runtime_context_uninitialized", "Runtime is not initialized", function() {
      Runtime.context();
    });
    Runtime.reset();

    TestRuntimeSupport.runEachRuntimeArch(function(_name, arch) {
      var firstSession:Session = null;
      var secondSession:Session = null;
      var firstContext:Context = null;
      var shortcutStream:Stream = null;
      try {
        firstSession = Runtime.init(arch, true);
        if (Runtime.session() != firstSession) throw "runtime_session_identity";
        firstContext = Runtime.context();
        if (firstContext.arch != arch) throw "runtime_context_arch";
        Runtime.sync();

        shortcutStream = Runtime.stream();
        if (shortcutStream == null) throw "runtime_stream_null";
        shortcutStream.sync();
        shortcutStream.close();
        shortcutStream = null;

        if (Runtime.profiler() == null) throw "runtime_profiler_null";

        Runtime.reset();
        expectThrows("runtime_session_after_reset", "runtime session is invalid", function() {
          firstSession.context();
        });
        expectThrows("runtime_context_after_reset", "context is closed", function() {
          firstContext.sync();
        });

        firstSession = Runtime.init(arch);
        firstContext = Runtime.context();
        secondSession = Runtime.init(arch);
        if (firstSession == secondSession) throw "runtime_reinit_reused_session";
        expectThrows("runtime_session_after_reinit", "runtime session is invalid", function() {
          firstSession.sync();
        });
        expectThrows("runtime_context_after_reinit", "context is closed", function() {
          firstContext.sync();
        });
        Runtime.sync();
        Runtime.reset();
        expectThrows("runtime_new_session_after_reset", "runtime session is invalid", function() {
          secondSession.context();
        });
      } catch (e:Dynamic) {
        if (shortcutStream != null) shortcutStream.close();
        Runtime.reset();
        throw e;
      }
    });
  }
}
