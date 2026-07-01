package quadrants;

class Graph {
  static var currentAutoStream:Stream = null;

  public static function autoStream():Stream {
    if (currentAutoStream == null) {
      throw "Quadrants Graph.autoStream() is only valid inside Graph.parallel";
    }
    return currentAutoStream;
  }

  public static function parallel(context:Context, blocks:Array<Void->Void>):Void {
    if (context == null) {
      throw "Quadrants Graph.parallel requires a Context";
    }
    if (blocks == null) {
      throw "Quadrants Graph.parallel requires blocks";
    }
    if (blocks.length > 1 && !context.capabilities().streamParallel) {
      throw "Quadrants Graph.parallel requires capability streamParallel for multiple blocks; use Graph.sequence for explicit sequential execution";
    }
    var streams = new Array<Stream>();
    try {
      for (block in blocks) {
        if (block == null) {
          throw "Quadrants Graph.parallel blocks cannot contain null";
        }
        var stream = context.createStream();
        streams.push(stream);
        currentAutoStream = stream;
        block();
      }
      currentAutoStream = null;
      for (stream in streams) {
        stream.sync();
      }
    } catch (e:Dynamic) {
      currentAutoStream = null;
      for (stream in streams) {
        try stream.close() catch (_:Dynamic) {}
      }
      throw e;
    }
    for (stream in streams) {
      stream.close();
    }
  }

  public static function sequence(context:Context, blocks:Array<Void->Void>):Void {
    if (context == null) {
      throw "Quadrants Graph.sequence requires a Context";
    }
    if (blocks == null) {
      throw "Quadrants Graph.sequence requires blocks";
    }
    for (block in blocks) {
      if (block == null) {
        throw "Quadrants Graph.sequence blocks cannot contain null";
      }
      block();
    }
  }
}
