package quadrants.simt;

import quadrants.Subgroup;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

/**
 * Portable full-subgroup voting built from subgroup shuffles.
 *
 * The XOR butterfly only combines live partners.  For a non-power-of-two
 * width, lane zero accumulates every live lane and the final broadcast gives
 * every lane that same result.  This keeps all source lanes in range for
 * every width from one through sixty-four.
 */
class SubgroupVote {
  @:qdFunc
  public static function allTrueI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var reduced:I32 = ((value : Int) != 0) ? 1 : 0;
    var offset:Int = 1;
    while (offset < width) {
      var partner:Int = lane ^ offset;
      var source:Int = lane;
      if (lane < width && partner < width) source = partner;
      var other:I32 = Subgroup.shuffle(reduced, source);
      if (lane < width && partner < width) reduced = (reduced : Int) & (other : Int);
      offset = offset << 1;
    }
    return Subgroup.broadcast(reduced, 0);
  }

  @:qdFunc
  public static function anyTrueI32(value:I32):I32 {
    var lane:Int = Subgroup.invocationId();
    var width:Int = Subgroup.size();
    var reduced:I32 = ((value : Int) != 0) ? 1 : 0;
    var offset:Int = 1;
    while (offset < width) {
      var partner:Int = lane ^ offset;
      var source:Int = lane;
      if (lane < width && partner < width) source = partner;
      var other:I32 = Subgroup.shuffle(reduced, source);
      if (lane < width && partner < width) reduced = (reduced : Int) | (other : Int);
      offset = offset << 1;
    }
    return Subgroup.broadcast(reduced, 0);
  }

  @:qdFunc
  public static function allTrue(value:Bool):I32 {
    var predicate:I32 = value ? 1 : 0;
    return allTrueI32(predicate);
  }

  @:qdFunc
  public static function anyTrue(value:Bool):I32 {
    var predicate:I32 = value ? 1 : 0;
    return anyTrueI32(predicate);
  }

  @:qdFunc
  public static function allEqualI32(value:I32):I32 {
    var reference:I32 = Subgroup.broadcast(value, 0);
    var equal:I32 = ((value : Int) == (reference : Int)) ? 1 : 0;
    return allTrueI32(equal);
  }

  @:qdFunc
  public static function allTrueU32(value:U32):I32 {
    var predicate:I32 = ((value : haxe.Int64) != 0) ? 1 : 0;
    return allTrueI32(predicate);
  }

  @:qdFunc
  public static function anyTrueU32(value:U32):I32 {
    var predicate:I32 = ((value : haxe.Int64) != 0) ? 1 : 0;
    return anyTrueI32(predicate);
  }

  @:qdFunc
  public static function allEqualU32(value:U32):I32 {
    var reference:U32 = Subgroup.broadcast(value, 0);
    var equal:I32 = ((value : haxe.Int64) == (reference : haxe.Int64)) ? 1 : 0;
    return allTrueI32(equal);
  }

  @:qdFunc
  public static function allTrueI64(value:I64):I32 {
    var predicate:I32 = ((value : haxe.Int64) != 0) ? 1 : 0;
    return allTrueI32(predicate);
  }

  @:qdFunc
  public static function anyTrueI64(value:I64):I32 {
    var predicate:I32 = ((value : haxe.Int64) != 0) ? 1 : 0;
    return anyTrueI32(predicate);
  }

  @:qdFunc
  public static function allEqualI64(value:I64):I32 {
    var reference:I64 = Subgroup.broadcast(value, 0);
    var equal:I32 = ((value : haxe.Int64) == (reference : haxe.Int64)) ? 1 : 0;
    return allTrueI32(equal);
  }

  @:qdFunc
  public static function allTrueU64(value:U64):I32 {
    var predicate:I32 = ((value : haxe.Int64) != 0) ? 1 : 0;
    return allTrueI32(predicate);
  }

  @:qdFunc
  public static function anyTrueU64(value:U64):I32 {
    var predicate:I32 = ((value : haxe.Int64) != 0) ? 1 : 0;
    return anyTrueI32(predicate);
  }

  @:qdFunc
  public static function allEqualU64(value:U64):I32 {
    var reference:U64 = Subgroup.broadcast(value, 0);
    var equal:I32 = ((value : haxe.Int64) == (reference : haxe.Int64)) ? 1 : 0;
    return allTrueI32(equal);
  }

  @:qdFunc
  public static function allTrueF32(value:F32):I32 {
    var predicate:I32 = ((value : Float) != 0.0) ? 1 : 0;
    return allTrueI32(predicate);
  }

  @:qdFunc
  public static function anyTrueF32(value:F32):I32 {
    var predicate:I32 = ((value : Float) != 0.0) ? 1 : 0;
    return anyTrueI32(predicate);
  }

  @:qdFunc
  public static function allEqualF32(value:F32):I32 {
    var reference:F32 = Subgroup.broadcast(value, 0);
    var equal:I32 = ((value : Float) == (reference : Float)) ? 1 : 0;
    return allTrueI32(equal);
  }

  @:qdFunc
  public static function allTrueF64(value:F64):I32 {
    var predicate:I32 = ((value : Float) != 0.0) ? 1 : 0;
    return allTrueI32(predicate);
  }

  @:qdFunc
  public static function anyTrueF64(value:F64):I32 {
    var predicate:I32 = ((value : Float) != 0.0) ? 1 : 0;
    return anyTrueI32(predicate);
  }

  @:qdFunc
  public static function allEqualF64(value:F64):I32 {
    var reference:F64 = Subgroup.broadcast(value, 0);
    var equal:I32 = ((value : Float) == (reference : Float)) ? 1 : 0;
    return allTrueI32(equal);
  }

  // Floating allEqual follows native == semantics: +0.0 equals -0.0 and
  // every NaN comparison is false, so a subgroup containing any NaN is not equal.
}
