package quadrants;

#if !macro
import quadrants.Native.QStreamEvent;
#end

class StreamEvent {
  #if !macro
  final context:Context;
  final handle:QStreamEvent;
  var closed:Bool = false;

  public function new(context:Context) {
    if (Native.stream_supports_events(context.nativeHandle()) == 0) {
      throw "Quadrants stream events require a CUDA or AMDGPU context";
    }
    this.context = context;
    this.handle = Native.stream_event_create(context.nativeHandle());
  }

  public function nativeHandle():QStreamEvent {
    if (closed) {
      throw "Quadrants stream event is closed";
    }
    return handle;
  }

  public function recordOn(stream:Stream):Void {
    Native.stream_event_record(context.nativeHandle(), nativeHandle(), stream.nativeHandle());
  }

  public inline function record(stream:Stream):Void {
    recordOn(stream);
  }

  public function sync():Void {
    Native.stream_event_sync(context.nativeHandle(), nativeHandle());
  }

  public function close():Void {
    if (!closed) {
      Native.stream_event_close(handle);
      closed = true;
    }
  }
  #end
}
