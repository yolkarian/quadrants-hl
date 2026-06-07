package quadrants.profiler;

enum abstract CuptiMetricPreset(Int) from Int to Int {
  var Default = 0;
  var GlobalAccess = 1;
  var SharedAccess = 2;
  var AtomicAccess = 3;
  var CacheHitRate = 4;
  var DeviceUtilization = 5;
}
