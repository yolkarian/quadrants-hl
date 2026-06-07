package quadrants.profiler;

enum abstract ProfilerToolkit(Int) from Int to Int {
  var Default = 0;
  var Cupti = 1;

  public inline function nativeName():String {
    return switch (this) {
      case Default: "default";
      case Cupti: "cupti";
      default: "default";
    }
  }
}
