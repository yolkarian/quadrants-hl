package quadrants;

class StreamParallel {
  public static function block(work:()->Void):Void {
    if (work == null) {
      throw "Quadrants StreamParallel.block requires a block closure";
    }
    throw "Quadrants StreamParallel.block is a kernel-only marker; HashLink currently rejects it at compile time because native multi-stream lowering is not supported";
  }
}
