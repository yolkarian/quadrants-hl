package quadrants.simt;

import quadrants.Subgroup;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

/**
 * Whole-subgroup prefix scans using only portable shuffles.
 *
 * Each Hillis-Steele stage executes its shuffle in uniform control flow.  Lanes
 * below the stage offset shuffle from themselves and do not combine, so every
 * subgroup width from 1 through 64 terminates without an out-of-range source.
 * A lane outside the reported subgroup width keeps its input unchanged.
 */
class SubgroupScan {
  @:qdFunc
  public static function subgroupScanLessThanU64(lhs:U64, rhs:U64):Bool {
    var lhsNegative:Bool = (lhs : haxe.Int64) < 0;
    var rhsNegative:Bool = (rhs : haxe.Int64) < 0;
    var result:Bool = (lhs : haxe.Int64) < (rhs : haxe.Int64);
    if (lhsNegative != rhsNegative) result = !lhsNegative;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAddI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) + (current : Int);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAddI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) + (current : Int);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMulI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) * (current : Int);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMulI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) * (current : Int);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = 1;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMinI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : Int) < (current : Int);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMinI32(value:I32, identity:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : Int) < (current : Int);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMaxI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : Int) < (previous : Int);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMaxI32(value:I32, identity:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : Int) < (previous : Int);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAddU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) + (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAddU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) + (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMulU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) * (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMulU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) * (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = 1;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMinU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : haxe.Int64) < (current : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMinU32(value:U32, identity:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : haxe.Int64) < (current : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMaxU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : haxe.Int64) < (previous : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMaxU32(value:U32, identity:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : haxe.Int64) < (previous : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAddI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) + (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAddI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) + (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMulI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) * (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMulI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) * (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = 1;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMinI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : haxe.Int64) < (current : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMinI64(value:I64, identity:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : haxe.Int64) < (current : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMaxI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : haxe.Int64) < (previous : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMaxI64(value:I64, identity:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : haxe.Int64) < (previous : haxe.Int64);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAddU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) + (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAddU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) + (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMulU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) * (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMulU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) * (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = 1;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMinU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      var replace:Bool = subgroupScanLessThanU64(previous, current);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMinU64(value:U64, identity:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      var replace:Bool = subgroupScanLessThanU64(previous, current);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMaxU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      var replace:Bool = subgroupScanLessThanU64(current, previous);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMaxU64(value:U64, identity:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      var replace:Bool = subgroupScanLessThanU64(current, previous);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAddF32(value:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) + (current : Float);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAddF32(value:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) + (current : Float);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F32 = Subgroup.shuffle(current, source);
    var result:F32 = value;
    if (lane == 0 && lane < width) result = 0.0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMulF32(value:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) * (current : Float);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMulF32(value:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) * (current : Float);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F32 = Subgroup.shuffle(current, source);
    var result:F32 = value;
    if (lane == 0 && lane < width) result = 1.0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMinF32(value:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : Float) < (current : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMinF32(value:F32, identity:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : Float) < (current : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F32 = Subgroup.shuffle(current, source);
    var result:F32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMaxF32(value:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : Float) < (previous : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMaxF32(value:F32, identity:F32):F32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F32 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : Float) < (previous : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F32 = Subgroup.shuffle(current, source);
    var result:F32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAddF64(value:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) + (current : Float);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAddF64(value:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) + (current : Float);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F64 = Subgroup.shuffle(current, source);
    var result:F64 = value;
    if (lane == 0 && lane < width) result = 0.0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMulF64(value:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) * (current : Float);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMulF64(value:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Float) * (current : Float);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F64 = Subgroup.shuffle(current, source);
    var result:F64 = value;
    if (lane == 0 && lane < width) result = 1.0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMinF64(value:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : Float) < (current : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMinF64(value:F64, identity:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      var replace:Bool = (previous : Float) < (current : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F64 = Subgroup.shuffle(current, source);
    var result:F64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveMaxF64(value:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : Float) < (previous : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveMaxF64(value:F64, identity:F64):F64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:F64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:F64 = Subgroup.shuffle(current, source);
      var replace:Bool = (current : Float) < (previous : Float);
      if (lane < width && lane >= offset && replace) current = previous;
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:F64 = Subgroup.shuffle(current, source);
    var result:F64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAndI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) & (current : Int);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAndI32(value:I32, identity:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) & (current : Int);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveOrI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) | (current : Int);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveOrI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) | (current : Int);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveXorI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) ^ (current : Int);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveXorI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : Int) ^ (current : Int);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I32 = Subgroup.shuffle(current, source);
    var result:I32 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAndU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) & (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAndU32(value:U32, identity:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) & (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveOrU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) | (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveOrU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) | (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveXorU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) ^ (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveXorU32(value:U32):U32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U32 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U32 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) ^ (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U32 = Subgroup.shuffle(current, source);
    var result:U32 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAndI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) & (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAndI64(value:I64, identity:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) & (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveOrI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) | (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveOrI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) | (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveXorI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) ^ (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveXorI64(value:I64):I64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:I64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:I64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) ^ (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:I64 = Subgroup.shuffle(current, source);
    var result:I64 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveAndU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) & (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveAndU64(value:U64, identity:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) & (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = identity;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveOrU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) | (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveOrU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) | (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

  @:qdFunc
  public static function subgroupInclusiveXorU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) ^ (current : haxe.Int64);
      offset = offset << 1;
    }
    return current;
  }

  @:qdFunc
  public static function subgroupExclusiveXorU64(value:U64):U64 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var current:U64 = value;
    var offset:Int = 1;
    while (offset < width) {
      var source:Int = lane;
      if (lane < width && lane >= offset) source = lane - offset;
      var previous:U64 = Subgroup.shuffle(current, source);
      if (lane < width && lane >= offset) current = (previous : haxe.Int64) ^ (current : haxe.Int64);
      offset = offset << 1;
    }
    var source:Int = lane;
    if (lane > 0 && lane < width) source = lane - 1;
    var shifted:U64 = Subgroup.shuffle(current, source);
    var result:U64 = value;
    if (lane == 0 && lane < width) result = 0;
    if (lane > 0 && lane < width) result = shifted;
    return result;
  }

}
