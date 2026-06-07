package quadrants.profiler;

@:final class MemoryProfilerStatus {
  public final availability:ProfilerAvailability;
  public final reason:String;

  public function new(availability:ProfilerAvailability, reason:String = "") {
    this.availability = availability;
    this.reason = reason;
  }

  public inline function isAvailable():Bool {
    return availability == ProfilerAvailability.Available;
  }
}
