package quadrants.simt;

import quadrants.Subgroup;
import quadrants.Types.F32;
import quadrants.Types.I32;

/**
 * Segmented subgroup reductions: per-lane inclusive reductions that reset at
 * every non-zero `headFlag`, mirroring the Python binding's
 * `segmented_reduce_{add,min,max}_tiled` semantics over the active subgroup.
 *
 * Lane `i` combines values from the nearest lane at or below `i` whose
 * `headFlag` is non-zero (lane 0 is an implicit head). The implementation is
 * the classic flag-carrying Hillis-Steele scan over `Subgroup.shuffle`, so it
 * stays portable across every backend that supports subgroup shuffles, and it
 * degenerates to the identity on width-1 subgroups (for example the CPU
 * backend). Callers must keep control flow uniform across the subgroup.
 */
class SubgroupSegmented {
  @:qdFunc
  public static function segmentedReduceAddI32(value:I32, headFlag:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var flag:Int = 0;
    if ((headFlag : Int) != 0) flag = 1;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var previousFlag:Int = Subgroup.shuffle(flag, source);
      if (lane < width && lane >= offset && flag == 0) current = (previous : Int) + (current : Int);
      if (lane < width && lane >= offset) flag = flag | previousFlag;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function segmentedReduceMinI32(value:I32, headFlag:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var flag:Int = 0;
    if ((headFlag : Int) != 0) flag = 1;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var previousFlag:Int = Subgroup.shuffle(flag, source);
      var replace:Bool = (previous : Int) < (current : Int);
      if (lane < width && lane >= offset && flag == 0 && replace) current = previous;
      if (lane < width && lane >= offset) flag = flag | previousFlag;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function segmentedReduceMaxI32(value:I32, headFlag:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var flag:Int = 0;
    if ((headFlag : Int) != 0) flag = 1;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var previousFlag:Int = Subgroup.shuffle(flag, source);
      var replace:Bool = (previous : Int) > (current : Int);
      if (lane < width && lane >= offset && flag == 0 && replace) current = previous;
      if (lane < width && lane >= offset) flag = flag | previousFlag;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function segmentedReduceAddF32(value:F32, headFlag:I32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var flag:Int = 0;
    if ((headFlag : Int) != 0) flag = 1;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var previousFlag:Int = Subgroup.shuffle(flag, source);
      if (lane < width && lane >= offset && flag == 0) current = (previous : Float) + (current : Float);
      if (lane < width && lane >= offset) flag = flag | previousFlag;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function segmentedReduceMinF32(value:F32, headFlag:I32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var flag:Int = 0;
    if ((headFlag : Int) != 0) flag = 1;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var previousFlag:Int = Subgroup.shuffle(flag, source);
      var replace:Bool = (previous : Float) < (current : Float);
      if (lane < width && lane >= offset && flag == 0 && replace) current = previous;
      if (lane < width && lane >= offset) flag = flag | previousFlag;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function segmentedReduceMaxF32(value:F32, headFlag:I32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var flag:Int = 0;
    if ((headFlag : Int) != 0) flag = 1;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var previousFlag:Int = Subgroup.shuffle(flag, source);
      var replace:Bool = (previous : Float) > (current : Float);
      if (lane < width && lane >= offset && flag == 0 && replace) current = previous;
      if (lane < width && lane >= offset) flag = flag | previousFlag;
      offset = offset << 1;
    }
    return current;
  }
}
