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
