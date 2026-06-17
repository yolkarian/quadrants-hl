package quadrants;

#if !macro
import quadrants.Native.QStream;
#end

class Stream {
  #if !macro
  final context:Context;
  final handle:QStream;
  var closed:Bool = false;

  public function new(context:Context) {
    this.context = context;
    this.handle = Native.stream_create(context.nativeHandle());
  }

  public function nativeHandle():QStream {
    if (closed) {
      throw "Quadrants stream is closed";
    }
    return handle;
  }

  public function supportsEvents():Bool {
    return Native.stream_supports_events(context.nativeHandle()) != 0;
  }

  public function createEvent():StreamEvent {
    return new StreamEvent(context);
  }

  public function recordEvent(event:StreamEvent):Void {
    event.recordOn(this);
  }

  public function waitEvent(event:StreamEvent):Void {
    Native.stream_wait_event(context.nativeHandle(), nativeHandle(), event.nativeHandle());
  }

  public inline function wait(event:StreamEvent):Void {
    waitEvent(event);
  }

  public function sync():Void {
    Native.stream_sync(context.nativeHandle(), nativeHandle());
  }

  public function close():Void {
    if (!closed) {
      Native.stream_close(handle);
      closed = true;
    }
  }
  #end
}
