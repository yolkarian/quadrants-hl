package quadrants.profiler;

@:final class MemoryProfilerStatus {
  public final availability:ProfilerAvailability;
  public final reason:String;
  public final allocatedBytes:haxe.Int64;
  public final snodeBytes:haxe.Int64;
  public final ndarrayBytes:haxe.Int64;

  public function new(availability:ProfilerAvailability,
      reason:String = "",
      ?allocatedBytes:haxe.Int64,
      ?snodeBytes:haxe.Int64,
      ?ndarrayBytes:haxe.Int64) {
    var zero = haxe.Int64.make(0, 0);
    this.availability = availability;
    this.reason = reason;
    this.allocatedBytes = allocatedBytes == null ? zero : allocatedBytes;
    this.snodeBytes = snodeBytes == null ? zero : snodeBytes;
    this.ndarrayBytes = ndarrayBytes == null ? zero : ndarrayBytes;
  }

  public inline function isAvailable():Bool {
    return availability == ProfilerAvailability.Available;
  }
}
