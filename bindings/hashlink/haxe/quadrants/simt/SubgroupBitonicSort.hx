package quadrants.simt;

import quadrants.Subgroup;
import quadrants.Vector;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

/**
 * Register-resident subgroup key/value sorting.
 *
 * bitonicSortAscendingT/bitonicSortDescendingT return Vector<T> in
 * [key, value] order, which the current KernelBuilder flattens without a
 * heap allocation.  These homogeneous pair facades use lexicographic
 * (key, value, originalLane) order.  For a payload whose type differs from
 * its key, call bitonicSort*LaneT(key) and shuffle that typed payload from
 * the returned source lane; that preserves type safety without a 6x6 API.
 *
 * Finite floating keys/values have deterministic ascending and descending
 * ordering. NaNs are intentionally unordered: a NaN comparison falls through
 * to the next tie-breaker, so callers needing a total order must prefilter
 * or bit-cast keys.
 */
class SubgroupBitonicSort {
  @:qdFunc
  public static function subgroupSortLessThanI32(lhs:I32, rhs:I32):Bool {
    return (lhs : Int) < (rhs : Int);
  }

  @:qdFunc
  public static function subgroupSortPairLessI32(lhsKey:I32, lhsValue:I32, lhsLane:Int, rhsKey:I32, rhsValue:I32, rhsLane:Int, useValueTie:Bool):Bool {
    var result:Bool = lhsLane < rhsLane;
    var keyLess:Bool = subgroupSortLessThanI32(lhsKey, rhsKey);
    var keyGreater:Bool = subgroupSortLessThanI32(rhsKey, lhsKey);
    if (keyLess) result = true;
    if (keyGreater) result = false;
    if (useValueTie && !keyLess && !keyGreater) {
      var valueLess:Bool = subgroupSortLessThanI32(lhsValue, rhsValue);
      var valueGreater:Bool = subgroupSortLessThanI32(rhsValue, lhsValue);
      if (valueLess) result = true;
      if (valueGreater) result = false;
    }
    return result;
  }

  @:qdFunc
  public static function subgroupSortSourceI32(key:I32, value:I32, useValueTie:Bool, descending:Bool):Int {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var currentKey:I32 = key;
    var currentValue:I32 = value;
    var currentLane:Int = lane;
    var powerOfTwo:Bool = width > 0 && (width & (width - 1)) == 0;
    if (powerOfTwo) {
      var span:Int = 2;
      while (span <= width) {
        var stride:Int = span >> 1;
        while (stride > 0) {
          var partner:Int = lane ^ stride;
          var source:Int = lane;
          if (lane < width && partner < width) source = partner;
          var theirKey:I32 = Subgroup.shuffle(currentKey, source);
          var theirValue:I32 = Subgroup.shuffle(currentValue, source);
          var theirLane:Int = Subgroup.shuffle(currentLane, source);
          var theirLess:Bool = subgroupSortPairLessI32(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
          var mineLess:Bool = subgroupSortPairLessI32(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
          var ascendingStage:Bool = (lane & span) == 0;
          if (descending) ascendingStage = !ascendingStage;
          var lowPartner:Bool = (lane & stride) == 0;
          var takeLow:Bool = lowPartner == ascendingStage;
          var takeOther:Bool = false;
          if (lane < width && partner < width) {
            if (takeLow && theirLess) takeOther = true;
            if (!takeLow && mineLess) takeOther = true;
          }
          if (takeOther) {
            currentKey = theirKey;
            currentValue = theirValue;
            currentLane = theirLane;
          }
          stride = stride >> 1;
        }
        span = span << 1;
      }
    } else {
      // Bitonic networks require a power-of-two width.  This adjacent
      // compare-exchange network is the register-only exact fallback for
      // arbitrary live widths, including 1..64 non-power-of-two groups.
      var phase:Int = 0;
      while (phase < width) {
        var lowPartner:Bool = (lane & 1) == (phase & 1);
        var partner:Int = lane;
        if (lane < width) {
          if (lowPartner && lane + 1 < width) partner = lane + 1;
          if (!lowPartner && lane > 0) partner = lane - 1;
        }
        var theirKey:I32 = Subgroup.shuffle(currentKey, partner);
        var theirValue:I32 = Subgroup.shuffle(currentValue, partner);
        var theirLane:Int = Subgroup.shuffle(currentLane, partner);
        var theirLess:Bool = subgroupSortPairLessI32(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
        var mineLess:Bool = subgroupSortPairLessI32(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
        var takeOther:Bool = false;
        if (lane < width && partner != lane) {
          if (!descending) {
            if (lowPartner && theirLess) takeOther = true;
            if (!lowPartner && mineLess) takeOther = true;
          } else {
            if (lowPartner && mineLess) takeOther = true;
            if (!lowPartner && theirLess) takeOther = true;
          }
        }
        if (takeOther) {
          currentKey = theirKey;
          currentValue = theirValue;
          currentLane = theirLane;
        }
        phase = phase + 1;
      }
    }
    return currentLane;
  }

  @:qdFunc
  public static function bitonicSortAscendingLaneI32(key:I32):Int {
    return subgroupSortSourceI32(key, key, false, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyValueLaneI32(key:I32, value:I32):Int {
    return subgroupSortSourceI32(key, value, true, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyI32(key:I32, value:I32):I32 {
    var source:Int = bitonicSortAscendingKeyValueLaneI32(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingValueI32(key:I32, value:I32):I32 {
    var source:Int = bitonicSortAscendingKeyValueLaneI32(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingI32(key:I32, value:I32):Vector<I32> {
    return Vector.ofArray([
      bitonicSortAscendingKeyI32(key, value),
      bitonicSortAscendingValueI32(key, value)
    ]);
  }

  @:qdFunc
  public static function bitonicSortDescendingLaneI32(key:I32):Int {
    return subgroupSortSourceI32(key, key, false, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyValueLaneI32(key:I32, value:I32):Int {
    return subgroupSortSourceI32(key, value, true, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyI32(key:I32, value:I32):I32 {
    var source:Int = bitonicSortDescendingKeyValueLaneI32(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingValueI32(key:I32, value:I32):I32 {
    var source:Int = bitonicSortDescendingKeyValueLaneI32(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingI32(key:I32, value:I32):Vector<I32> {
    return Vector.ofArray([
      bitonicSortDescendingKeyI32(key, value),
      bitonicSortDescendingValueI32(key, value)
    ]);
  }

  @:qdFunc
  public static function subgroupSortLessThanU32(lhs:U32, rhs:U32):Bool {
    return (lhs : haxe.Int64) < (rhs : haxe.Int64);
  }

  @:qdFunc
  public static function subgroupSortPairLessU32(lhsKey:U32, lhsValue:U32, lhsLane:Int, rhsKey:U32, rhsValue:U32, rhsLane:Int, useValueTie:Bool):Bool {
    var result:Bool = lhsLane < rhsLane;
    var keyLess:Bool = subgroupSortLessThanU32(lhsKey, rhsKey);
    var keyGreater:Bool = subgroupSortLessThanU32(rhsKey, lhsKey);
    if (keyLess) result = true;
    if (keyGreater) result = false;
    if (useValueTie && !keyLess && !keyGreater) {
      var valueLess:Bool = subgroupSortLessThanU32(lhsValue, rhsValue);
      var valueGreater:Bool = subgroupSortLessThanU32(rhsValue, lhsValue);
      if (valueLess) result = true;
      if (valueGreater) result = false;
    }
    return result;
  }

  @:qdFunc
  public static function subgroupSortSourceU32(key:U32, value:U32, useValueTie:Bool, descending:Bool):Int {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var currentKey:U32 = key;
    var currentValue:U32 = value;
    var currentLane:Int = lane;
    var powerOfTwo:Bool = width > 0 && (width & (width - 1)) == 0;
    if (powerOfTwo) {
      var span:Int = 2;
      while (span <= width) {
        var stride:Int = span >> 1;
        while (stride > 0) {
          var partner:Int = lane ^ stride;
          var source:Int = lane;
          if (lane < width && partner < width) source = partner;
          var theirKey:U32 = Subgroup.shuffle(currentKey, source);
          var theirValue:U32 = Subgroup.shuffle(currentValue, source);
          var theirLane:Int = Subgroup.shuffle(currentLane, source);
          var theirLess:Bool = subgroupSortPairLessU32(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
          var mineLess:Bool = subgroupSortPairLessU32(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
          var ascendingStage:Bool = (lane & span) == 0;
          if (descending) ascendingStage = !ascendingStage;
          var lowPartner:Bool = (lane & stride) == 0;
          var takeLow:Bool = lowPartner == ascendingStage;
          var takeOther:Bool = false;
          if (lane < width && partner < width) {
            if (takeLow && theirLess) takeOther = true;
            if (!takeLow && mineLess) takeOther = true;
          }
          if (takeOther) {
            currentKey = theirKey;
            currentValue = theirValue;
            currentLane = theirLane;
          }
          stride = stride >> 1;
        }
        span = span << 1;
      }
    } else {
      // Bitonic networks require a power-of-two width.  This adjacent
      // compare-exchange network is the register-only exact fallback for
      // arbitrary live widths, including 1..64 non-power-of-two groups.
      var phase:Int = 0;
      while (phase < width) {
        var lowPartner:Bool = (lane & 1) == (phase & 1);
        var partner:Int = lane;
        if (lane < width) {
          if (lowPartner && lane + 1 < width) partner = lane + 1;
          if (!lowPartner && lane > 0) partner = lane - 1;
        }
        var theirKey:U32 = Subgroup.shuffle(currentKey, partner);
        var theirValue:U32 = Subgroup.shuffle(currentValue, partner);
        var theirLane:Int = Subgroup.shuffle(currentLane, partner);
        var theirLess:Bool = subgroupSortPairLessU32(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
        var mineLess:Bool = subgroupSortPairLessU32(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
        var takeOther:Bool = false;
        if (lane < width && partner != lane) {
          if (!descending) {
            if (lowPartner && theirLess) takeOther = true;
            if (!lowPartner && mineLess) takeOther = true;
          } else {
            if (lowPartner && mineLess) takeOther = true;
            if (!lowPartner && theirLess) takeOther = true;
          }
        }
        if (takeOther) {
          currentKey = theirKey;
          currentValue = theirValue;
          currentLane = theirLane;
        }
        phase = phase + 1;
      }
    }
    return currentLane;
  }

  @:qdFunc
  public static function bitonicSortAscendingLaneU32(key:U32):Int {
    return subgroupSortSourceU32(key, key, false, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyValueLaneU32(key:U32, value:U32):Int {
    return subgroupSortSourceU32(key, value, true, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyU32(key:U32, value:U32):U32 {
    var source:Int = bitonicSortAscendingKeyValueLaneU32(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingValueU32(key:U32, value:U32):U32 {
    var source:Int = bitonicSortAscendingKeyValueLaneU32(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingU32(key:U32, value:U32):Vector<U32> {
    return Vector.ofArray([
      bitonicSortAscendingKeyU32(key, value),
      bitonicSortAscendingValueU32(key, value)
    ]);
  }

  @:qdFunc
  public static function bitonicSortDescendingLaneU32(key:U32):Int {
    return subgroupSortSourceU32(key, key, false, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyValueLaneU32(key:U32, value:U32):Int {
    return subgroupSortSourceU32(key, value, true, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyU32(key:U32, value:U32):U32 {
    var source:Int = bitonicSortDescendingKeyValueLaneU32(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingValueU32(key:U32, value:U32):U32 {
    var source:Int = bitonicSortDescendingKeyValueLaneU32(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingU32(key:U32, value:U32):Vector<U32> {
    return Vector.ofArray([
      bitonicSortDescendingKeyU32(key, value),
      bitonicSortDescendingValueU32(key, value)
    ]);
  }

  @:qdFunc
  public static function subgroupSortLessThanI64(lhs:I64, rhs:I64):Bool {
    return (lhs : haxe.Int64) < (rhs : haxe.Int64);
  }

  @:qdFunc
  public static function subgroupSortPairLessI64(lhsKey:I64, lhsValue:I64, lhsLane:Int, rhsKey:I64, rhsValue:I64, rhsLane:Int, useValueTie:Bool):Bool {
    var result:Bool = lhsLane < rhsLane;
    var keyLess:Bool = subgroupSortLessThanI64(lhsKey, rhsKey);
    var keyGreater:Bool = subgroupSortLessThanI64(rhsKey, lhsKey);
    if (keyLess) result = true;
    if (keyGreater) result = false;
    if (useValueTie && !keyLess && !keyGreater) {
      var valueLess:Bool = subgroupSortLessThanI64(lhsValue, rhsValue);
      var valueGreater:Bool = subgroupSortLessThanI64(rhsValue, lhsValue);
      if (valueLess) result = true;
      if (valueGreater) result = false;
    }
    return result;
  }

  @:qdFunc
  public static function subgroupSortSourceI64(key:I64, value:I64, useValueTie:Bool, descending:Bool):Int {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var currentKey:I64 = key;
    var currentValue:I64 = value;
    var currentLane:Int = lane;
    var powerOfTwo:Bool = width > 0 && (width & (width - 1)) == 0;
    if (powerOfTwo) {
      var span:Int = 2;
      while (span <= width) {
        var stride:Int = span >> 1;
        while (stride > 0) {
          var partner:Int = lane ^ stride;
          var source:Int = lane;
          if (lane < width && partner < width) source = partner;
          var theirKey:I64 = Subgroup.shuffle(currentKey, source);
          var theirValue:I64 = Subgroup.shuffle(currentValue, source);
          var theirLane:Int = Subgroup.shuffle(currentLane, source);
          var theirLess:Bool = subgroupSortPairLessI64(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
          var mineLess:Bool = subgroupSortPairLessI64(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
          var ascendingStage:Bool = (lane & span) == 0;
          if (descending) ascendingStage = !ascendingStage;
          var lowPartner:Bool = (lane & stride) == 0;
          var takeLow:Bool = lowPartner == ascendingStage;
          var takeOther:Bool = false;
          if (lane < width && partner < width) {
            if (takeLow && theirLess) takeOther = true;
            if (!takeLow && mineLess) takeOther = true;
          }
          if (takeOther) {
            currentKey = theirKey;
            currentValue = theirValue;
            currentLane = theirLane;
          }
          stride = stride >> 1;
        }
        span = span << 1;
      }
    } else {
      // Bitonic networks require a power-of-two width.  This adjacent
      // compare-exchange network is the register-only exact fallback for
      // arbitrary live widths, including 1..64 non-power-of-two groups.
      var phase:Int = 0;
      while (phase < width) {
        var lowPartner:Bool = (lane & 1) == (phase & 1);
        var partner:Int = lane;
        if (lane < width) {
          if (lowPartner && lane + 1 < width) partner = lane + 1;
          if (!lowPartner && lane > 0) partner = lane - 1;
        }
        var theirKey:I64 = Subgroup.shuffle(currentKey, partner);
        var theirValue:I64 = Subgroup.shuffle(currentValue, partner);
        var theirLane:Int = Subgroup.shuffle(currentLane, partner);
        var theirLess:Bool = subgroupSortPairLessI64(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
        var mineLess:Bool = subgroupSortPairLessI64(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
        var takeOther:Bool = false;
        if (lane < width && partner != lane) {
          if (!descending) {
            if (lowPartner && theirLess) takeOther = true;
            if (!lowPartner && mineLess) takeOther = true;
          } else {
            if (lowPartner && mineLess) takeOther = true;
            if (!lowPartner && theirLess) takeOther = true;
          }
        }
        if (takeOther) {
          currentKey = theirKey;
          currentValue = theirValue;
          currentLane = theirLane;
        }
        phase = phase + 1;
      }
    }
    return currentLane;
  }

  @:qdFunc
  public static function bitonicSortAscendingLaneI64(key:I64):Int {
    return subgroupSortSourceI64(key, key, false, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyValueLaneI64(key:I64, value:I64):Int {
    return subgroupSortSourceI64(key, value, true, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyI64(key:I64, value:I64):I64 {
    var source:Int = bitonicSortAscendingKeyValueLaneI64(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingValueI64(key:I64, value:I64):I64 {
    var source:Int = bitonicSortAscendingKeyValueLaneI64(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingI64(key:I64, value:I64):Vector<I64> {
    return Vector.ofArray([
      bitonicSortAscendingKeyI64(key, value),
      bitonicSortAscendingValueI64(key, value)
    ]);
  }

  @:qdFunc
  public static function bitonicSortDescendingLaneI64(key:I64):Int {
    return subgroupSortSourceI64(key, key, false, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyValueLaneI64(key:I64, value:I64):Int {
    return subgroupSortSourceI64(key, value, true, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyI64(key:I64, value:I64):I64 {
    var source:Int = bitonicSortDescendingKeyValueLaneI64(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingValueI64(key:I64, value:I64):I64 {
    var source:Int = bitonicSortDescendingKeyValueLaneI64(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingI64(key:I64, value:I64):Vector<I64> {
    return Vector.ofArray([
      bitonicSortDescendingKeyI64(key, value),
      bitonicSortDescendingValueI64(key, value)
    ]);
  }

  @:qdFunc
  public static function subgroupSortLessThanU64(lhs:U64, rhs:U64):Bool {
    var lhsNegative:Bool = (lhs : haxe.Int64) < 0;
    var rhsNegative:Bool = (rhs : haxe.Int64) < 0;
    var result:Bool = (lhs : haxe.Int64) < (rhs : haxe.Int64);
    if (lhsNegative != rhsNegative) result = !lhsNegative;
    return result;
  }

  @:qdFunc
  public static function subgroupSortPairLessU64(lhsKey:U64, lhsValue:U64, lhsLane:Int, rhsKey:U64, rhsValue:U64, rhsLane:Int, useValueTie:Bool):Bool {
    var result:Bool = lhsLane < rhsLane;
    var keyLess:Bool = subgroupSortLessThanU64(lhsKey, rhsKey);
    var keyGreater:Bool = subgroupSortLessThanU64(rhsKey, lhsKey);
    if (keyLess) result = true;
    if (keyGreater) result = false;
    if (useValueTie && !keyLess && !keyGreater) {
      var valueLess:Bool = subgroupSortLessThanU64(lhsValue, rhsValue);
      var valueGreater:Bool = subgroupSortLessThanU64(rhsValue, lhsValue);
      if (valueLess) result = true;
      if (valueGreater) result = false;
    }
    return result;
  }

  @:qdFunc
  public static function subgroupSortSourceU64(key:U64, value:U64, useValueTie:Bool, descending:Bool):Int {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var currentKey:U64 = key;
    var currentValue:U64 = value;
    var currentLane:Int = lane;
    var powerOfTwo:Bool = width > 0 && (width & (width - 1)) == 0;
    if (powerOfTwo) {
      var span:Int = 2;
      while (span <= width) {
        var stride:Int = span >> 1;
        while (stride > 0) {
          var partner:Int = lane ^ stride;
          var source:Int = lane;
          if (lane < width && partner < width) source = partner;
          var theirKey:U64 = Subgroup.shuffle(currentKey, source);
          var theirValue:U64 = Subgroup.shuffle(currentValue, source);
          var theirLane:Int = Subgroup.shuffle(currentLane, source);
          var theirLess:Bool = subgroupSortPairLessU64(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
          var mineLess:Bool = subgroupSortPairLessU64(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
          var ascendingStage:Bool = (lane & span) == 0;
          if (descending) ascendingStage = !ascendingStage;
          var lowPartner:Bool = (lane & stride) == 0;
          var takeLow:Bool = lowPartner == ascendingStage;
          var takeOther:Bool = false;
          if (lane < width && partner < width) {
            if (takeLow && theirLess) takeOther = true;
            if (!takeLow && mineLess) takeOther = true;
          }
          if (takeOther) {
            currentKey = theirKey;
            currentValue = theirValue;
            currentLane = theirLane;
          }
          stride = stride >> 1;
        }
        span = span << 1;
      }
    } else {
      // Bitonic networks require a power-of-two width.  This adjacent
      // compare-exchange network is the register-only exact fallback for
      // arbitrary live widths, including 1..64 non-power-of-two groups.
      var phase:Int = 0;
      while (phase < width) {
        var lowPartner:Bool = (lane & 1) == (phase & 1);
        var partner:Int = lane;
        if (lane < width) {
          if (lowPartner && lane + 1 < width) partner = lane + 1;
          if (!lowPartner && lane > 0) partner = lane - 1;
        }
        var theirKey:U64 = Subgroup.shuffle(currentKey, partner);
        var theirValue:U64 = Subgroup.shuffle(currentValue, partner);
        var theirLane:Int = Subgroup.shuffle(currentLane, partner);
        var theirLess:Bool = subgroupSortPairLessU64(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
        var mineLess:Bool = subgroupSortPairLessU64(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
        var takeOther:Bool = false;
        if (lane < width && partner != lane) {
          if (!descending) {
            if (lowPartner && theirLess) takeOther = true;
            if (!lowPartner && mineLess) takeOther = true;
          } else {
            if (lowPartner && mineLess) takeOther = true;
            if (!lowPartner && theirLess) takeOther = true;
          }
        }
        if (takeOther) {
          currentKey = theirKey;
          currentValue = theirValue;
          currentLane = theirLane;
        }
        phase = phase + 1;
      }
    }
    return currentLane;
  }

  @:qdFunc
  public static function bitonicSortAscendingLaneU64(key:U64):Int {
    return subgroupSortSourceU64(key, key, false, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyValueLaneU64(key:U64, value:U64):Int {
    return subgroupSortSourceU64(key, value, true, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyU64(key:U64, value:U64):U64 {
    var source:Int = bitonicSortAscendingKeyValueLaneU64(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingValueU64(key:U64, value:U64):U64 {
    var source:Int = bitonicSortAscendingKeyValueLaneU64(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingU64(key:U64, value:U64):Vector<U64> {
    return Vector.ofArray([
      bitonicSortAscendingKeyU64(key, value),
      bitonicSortAscendingValueU64(key, value)
    ]);
  }

  @:qdFunc
  public static function bitonicSortDescendingLaneU64(key:U64):Int {
    return subgroupSortSourceU64(key, key, false, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyValueLaneU64(key:U64, value:U64):Int {
    return subgroupSortSourceU64(key, value, true, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyU64(key:U64, value:U64):U64 {
    var source:Int = bitonicSortDescendingKeyValueLaneU64(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingValueU64(key:U64, value:U64):U64 {
    var source:Int = bitonicSortDescendingKeyValueLaneU64(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingU64(key:U64, value:U64):Vector<U64> {
    return Vector.ofArray([
      bitonicSortDescendingKeyU64(key, value),
      bitonicSortDescendingValueU64(key, value)
    ]);
  }

  @:qdFunc
  public static function subgroupSortLessThanF32(lhs:F32, rhs:F32):Bool {
    return (lhs : Float) < (rhs : Float);
  }

  @:qdFunc
  public static function subgroupSortPairLessF32(lhsKey:F32, lhsValue:F32, lhsLane:Int, rhsKey:F32, rhsValue:F32, rhsLane:Int, useValueTie:Bool):Bool {
    var result:Bool = lhsLane < rhsLane;
    var keyLess:Bool = subgroupSortLessThanF32(lhsKey, rhsKey);
    var keyGreater:Bool = subgroupSortLessThanF32(rhsKey, lhsKey);
    if (keyLess) result = true;
    if (keyGreater) result = false;
    if (useValueTie && !keyLess && !keyGreater) {
      var valueLess:Bool = subgroupSortLessThanF32(lhsValue, rhsValue);
      var valueGreater:Bool = subgroupSortLessThanF32(rhsValue, lhsValue);
      if (valueLess) result = true;
      if (valueGreater) result = false;
    }
    return result;
  }

  @:qdFunc
  public static function subgroupSortSourceF32(key:F32, value:F32, useValueTie:Bool, descending:Bool):Int {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var currentKey:F32 = key;
    var currentValue:F32 = value;
    var currentLane:Int = lane;
    var powerOfTwo:Bool = width > 0 && (width & (width - 1)) == 0;
    if (powerOfTwo) {
      var span:Int = 2;
      while (span <= width) {
        var stride:Int = span >> 1;
        while (stride > 0) {
          var partner:Int = lane ^ stride;
          var source:Int = lane;
          if (lane < width && partner < width) source = partner;
          var theirKey:F32 = Subgroup.shuffle(currentKey, source);
          var theirValue:F32 = Subgroup.shuffle(currentValue, source);
          var theirLane:Int = Subgroup.shuffle(currentLane, source);
          var theirLess:Bool = subgroupSortPairLessF32(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
          var mineLess:Bool = subgroupSortPairLessF32(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
          var ascendingStage:Bool = (lane & span) == 0;
          if (descending) ascendingStage = !ascendingStage;
          var lowPartner:Bool = (lane & stride) == 0;
          var takeLow:Bool = lowPartner == ascendingStage;
          var takeOther:Bool = false;
          if (lane < width && partner < width) {
            if (takeLow && theirLess) takeOther = true;
            if (!takeLow && mineLess) takeOther = true;
          }
          if (takeOther) {
            currentKey = theirKey;
            currentValue = theirValue;
            currentLane = theirLane;
          }
          stride = stride >> 1;
        }
        span = span << 1;
      }
    } else {
      // Bitonic networks require a power-of-two width.  This adjacent
      // compare-exchange network is the register-only exact fallback for
      // arbitrary live widths, including 1..64 non-power-of-two groups.
      var phase:Int = 0;
      while (phase < width) {
        var lowPartner:Bool = (lane & 1) == (phase & 1);
        var partner:Int = lane;
        if (lane < width) {
          if (lowPartner && lane + 1 < width) partner = lane + 1;
          if (!lowPartner && lane > 0) partner = lane - 1;
        }
        var theirKey:F32 = Subgroup.shuffle(currentKey, partner);
        var theirValue:F32 = Subgroup.shuffle(currentValue, partner);
        var theirLane:Int = Subgroup.shuffle(currentLane, partner);
        var theirLess:Bool = subgroupSortPairLessF32(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
        var mineLess:Bool = subgroupSortPairLessF32(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
        var takeOther:Bool = false;
        if (lane < width && partner != lane) {
          if (!descending) {
            if (lowPartner && theirLess) takeOther = true;
            if (!lowPartner && mineLess) takeOther = true;
          } else {
            if (lowPartner && mineLess) takeOther = true;
            if (!lowPartner && theirLess) takeOther = true;
          }
        }
        if (takeOther) {
          currentKey = theirKey;
          currentValue = theirValue;
          currentLane = theirLane;
        }
        phase = phase + 1;
      }
    }
    return currentLane;
  }

  @:qdFunc
  public static function bitonicSortAscendingLaneF32(key:F32):Int {
    return subgroupSortSourceF32(key, key, false, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyValueLaneF32(key:F32, value:F32):Int {
    return subgroupSortSourceF32(key, value, true, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyF32(key:F32, value:F32):F32 {
    var source:Int = bitonicSortAscendingKeyValueLaneF32(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingValueF32(key:F32, value:F32):F32 {
    var source:Int = bitonicSortAscendingKeyValueLaneF32(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingF32(key:F32, value:F32):Vector<F32> {
    return Vector.ofArray([
      bitonicSortAscendingKeyF32(key, value),
      bitonicSortAscendingValueF32(key, value)
    ]);
  }

  @:qdFunc
  public static function bitonicSortDescendingLaneF32(key:F32):Int {
    return subgroupSortSourceF32(key, key, false, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyValueLaneF32(key:F32, value:F32):Int {
    return subgroupSortSourceF32(key, value, true, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyF32(key:F32, value:F32):F32 {
    var source:Int = bitonicSortDescendingKeyValueLaneF32(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingValueF32(key:F32, value:F32):F32 {
    var source:Int = bitonicSortDescendingKeyValueLaneF32(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingF32(key:F32, value:F32):Vector<F32> {
    return Vector.ofArray([
      bitonicSortDescendingKeyF32(key, value),
      bitonicSortDescendingValueF32(key, value)
    ]);
  }

  @:qdFunc
  public static function subgroupSortLessThanF64(lhs:F64, rhs:F64):Bool {
    return (lhs : Float) < (rhs : Float);
  }

  @:qdFunc
  public static function subgroupSortPairLessF64(lhsKey:F64, lhsValue:F64, lhsLane:Int, rhsKey:F64, rhsValue:F64, rhsLane:Int, useValueTie:Bool):Bool {
    var result:Bool = lhsLane < rhsLane;
    var keyLess:Bool = subgroupSortLessThanF64(lhsKey, rhsKey);
    var keyGreater:Bool = subgroupSortLessThanF64(rhsKey, lhsKey);
    if (keyLess) result = true;
    if (keyGreater) result = false;
    if (useValueTie && !keyLess && !keyGreater) {
      var valueLess:Bool = subgroupSortLessThanF64(lhsValue, rhsValue);
      var valueGreater:Bool = subgroupSortLessThanF64(rhsValue, lhsValue);
      if (valueLess) result = true;
      if (valueGreater) result = false;
    }
    return result;
  }

  @:qdFunc
  public static function subgroupSortSourceF64(key:F64, value:F64, useValueTie:Bool, descending:Bool):Int {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var currentKey:F64 = key;
    var currentValue:F64 = value;
    var currentLane:Int = lane;
    var powerOfTwo:Bool = width > 0 && (width & (width - 1)) == 0;
    if (powerOfTwo) {
      var span:Int = 2;
      while (span <= width) {
        var stride:Int = span >> 1;
        while (stride > 0) {
          var partner:Int = lane ^ stride;
          var source:Int = lane;
          if (lane < width && partner < width) source = partner;
          var theirKey:F64 = Subgroup.shuffle(currentKey, source);
          var theirValue:F64 = Subgroup.shuffle(currentValue, source);
          var theirLane:Int = Subgroup.shuffle(currentLane, source);
          var theirLess:Bool = subgroupSortPairLessF64(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
          var mineLess:Bool = subgroupSortPairLessF64(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
          var ascendingStage:Bool = (lane & span) == 0;
          if (descending) ascendingStage = !ascendingStage;
          var lowPartner:Bool = (lane & stride) == 0;
          var takeLow:Bool = lowPartner == ascendingStage;
          var takeOther:Bool = false;
          if (lane < width && partner < width) {
            if (takeLow && theirLess) takeOther = true;
            if (!takeLow && mineLess) takeOther = true;
          }
          if (takeOther) {
            currentKey = theirKey;
            currentValue = theirValue;
            currentLane = theirLane;
          }
          stride = stride >> 1;
        }
        span = span << 1;
      }
    } else {
      // Bitonic networks require a power-of-two width.  This adjacent
      // compare-exchange network is the register-only exact fallback for
      // arbitrary live widths, including 1..64 non-power-of-two groups.
      var phase:Int = 0;
      while (phase < width) {
        var lowPartner:Bool = (lane & 1) == (phase & 1);
        var partner:Int = lane;
        if (lane < width) {
          if (lowPartner && lane + 1 < width) partner = lane + 1;
          if (!lowPartner && lane > 0) partner = lane - 1;
        }
        var theirKey:F64 = Subgroup.shuffle(currentKey, partner);
        var theirValue:F64 = Subgroup.shuffle(currentValue, partner);
        var theirLane:Int = Subgroup.shuffle(currentLane, partner);
        var theirLess:Bool = subgroupSortPairLessF64(theirKey, theirValue, theirLane, currentKey, currentValue, currentLane, useValueTie);
        var mineLess:Bool = subgroupSortPairLessF64(currentKey, currentValue, currentLane, theirKey, theirValue, theirLane, useValueTie);
        var takeOther:Bool = false;
        if (lane < width && partner != lane) {
          if (!descending) {
            if (lowPartner && theirLess) takeOther = true;
            if (!lowPartner && mineLess) takeOther = true;
          } else {
            if (lowPartner && mineLess) takeOther = true;
            if (!lowPartner && theirLess) takeOther = true;
          }
        }
        if (takeOther) {
          currentKey = theirKey;
          currentValue = theirValue;
          currentLane = theirLane;
        }
        phase = phase + 1;
      }
    }
    return currentLane;
  }

  @:qdFunc
  public static function bitonicSortAscendingLaneF64(key:F64):Int {
    return subgroupSortSourceF64(key, key, false, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyValueLaneF64(key:F64, value:F64):Int {
    return subgroupSortSourceF64(key, value, true, false);
  }

  @:qdFunc
  public static function bitonicSortAscendingKeyF64(key:F64, value:F64):F64 {
    var source:Int = bitonicSortAscendingKeyValueLaneF64(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingValueF64(key:F64, value:F64):F64 {
    var source:Int = bitonicSortAscendingKeyValueLaneF64(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortAscendingF64(key:F64, value:F64):Vector<F64> {
    return Vector.ofArray([
      bitonicSortAscendingKeyF64(key, value),
      bitonicSortAscendingValueF64(key, value)
    ]);
  }

  @:qdFunc
  public static function bitonicSortDescendingLaneF64(key:F64):Int {
    return subgroupSortSourceF64(key, key, false, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyValueLaneF64(key:F64, value:F64):Int {
    return subgroupSortSourceF64(key, value, true, true);
  }

  @:qdFunc
  public static function bitonicSortDescendingKeyF64(key:F64, value:F64):F64 {
    var source:Int = bitonicSortDescendingKeyValueLaneF64(key, value);
    return Subgroup.shuffle(key, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingValueF64(key:F64, value:F64):F64 {
    var source:Int = bitonicSortDescendingKeyValueLaneF64(key, value);
    return Subgroup.shuffle(value, source);
  }

  @:qdFunc
  public static function bitonicSortDescendingF64(key:F64, value:F64):Vector<F64> {
    return Vector.ofArray([
      bitonicSortDescendingKeyF64(key, value),
      bitonicSortDescendingValueF64(key, value)
    ]);
  }

}
