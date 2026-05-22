import quadrants.Context;
import quadrants.Kernel;
import quadrants.Stream;
import quadrants.StreamEvent;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestStreamEventRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

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
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx:Context) {
      var stream = ctx.stream();
      try {
        if (stream.supportsEvents() != ctx.supportsStreamEvents()) throw 'stream_event_capability_mismatch';
        if (!ctx.supportsStreamEvents()) {
          expectThrows('cpu_stream_event_create', 'CUDA or AMDGPU', function() {
            stream.createEvent();
          });
        }
      } catch (e:Dynamic) {
        stream.close();
        throw e;
      }
      stream.close();
    });

    TestRuntimeSupport.runEachRequestedDeviceContext(function(_name, ctx:Context) {
      var launchStream:Stream = null;
      var waitStream:Stream = null;
      var event:StreamEvent = null;
      var kernel:Kernel = null;
      var out:Tensor<I32> = null;
      try {
        if (!ctx.supportsStreamEvents()) {
          throw 'requested_device_stream_events_disabled';
        }
        launchStream = ctx.stream();
        waitStream = ctx.stream();
        event = launchStream.createEvent();
        out = new Tensor<I32>(ctx, [1]);
        kernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
          out[0] = 42;
        });
        kernel.launchOn(launchStream, out);
        launchStream.recordEvent(event);
        waitStream.waitEvent(event);
        waitStream.sync();
        expectEq('stream_event_wait', out.read(0), 42);
      } catch (e:Dynamic) {
        if (out != null) out.close();
        if (kernel != null) kernel.close();
        if (event != null) event.close();
        if (waitStream != null) waitStream.close();
        if (launchStream != null) launchStream.close();
        throw e;
      }
      if (out != null) out.close();
      if (kernel != null) kernel.close();
      if (event != null) event.close();
      if (waitStream != null) waitStream.close();
      if (launchStream != null) launchStream.close();
    });
  }
}
