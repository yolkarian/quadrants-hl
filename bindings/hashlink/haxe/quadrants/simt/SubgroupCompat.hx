package quadrants.simt;

import quadrants.Grid;
import quadrants.Subgroup;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

class SubgroupCompat {
  @:qdFunc
  public static function shuffleI32(value:I32, lane:Int):I32 {
    return Subgroup.shuffle(value, lane);
  }

  @:qdFunc
  public static function shuffleUpI32(value:I32, delta:Int):I32 {
    return Subgroup.shuffleUp(value, delta);
  }

  @:qdFunc
  public static function shuffleDownI32(value:I32, delta:Int):I32 {
    return Subgroup.shuffleDown(value, delta);
  }

  @:qdFunc
  public static function shuffleXorI32(value:I32, laneMask:Int):I32 {
    return Subgroup.shuffle(value, Subgroup.invocationId() ^ laneMask);
  }

  @:qdFunc
  public static function broadcastI32(value:I32, lane:Int):I32 {
    return Subgroup.broadcast(value, lane);
  }

  @:qdFunc
  public static function broadcastFirstI32(value:I32):I32 {
    return Subgroup.broadcast(value, 0);
  }

  @:qdFunc
  public static function shuffleU32(value:U32, lane:Int):U32 {
    return Subgroup.shuffle(value, lane);
  }

  @:qdFunc
  public static function shuffleXorU32(value:U32, laneMask:Int):U32 {
    return Subgroup.shuffle(value, Subgroup.invocationId() ^ laneMask);
  }

  @:qdFunc
  public static function broadcastFirstU32(value:U32):U32 {
    return Subgroup.broadcast(value, 0);
  }

  @:qdFunc
  public static function shuffleI64(value:I64, lane:Int):I64 {
    return Subgroup.shuffle(value, lane);
  }

  @:qdFunc
  public static function shuffleXorI64(value:I64, laneMask:Int):I64 {
    return Subgroup.shuffle(value, Subgroup.invocationId() ^ laneMask);
  }

  @:qdFunc
  public static function broadcastFirstI64(value:I64):I64 {
    return Subgroup.broadcast(value, 0);
  }

  @:qdFunc
  public static function shuffleU64(value:U64, lane:Int):U64 {
    return Subgroup.shuffle(value, lane);
  }

  @:qdFunc
  public static function shuffleXorU64(value:U64, laneMask:Int):U64 {
    return Subgroup.shuffle(value, Subgroup.invocationId() ^ laneMask);
  }

  @:qdFunc
  public static function broadcastFirstU64(value:U64):U64 {
    return Subgroup.broadcast(value, 0);
  }

  @:qdFunc
  public static function shuffleF32(value:F32, lane:Int):F32 {
    return Subgroup.shuffle(value, lane);
  }

  @:qdFunc
  public static function shuffleUpF32(value:F32, delta:Int):F32 {
    return Subgroup.shuffleUp(value, delta);
  }

  @:qdFunc
  public static function shuffleDownF32(value:F32, delta:Int):F32 {
    return Subgroup.shuffleDown(value, delta);
  }

  @:qdFunc
  public static function shuffleXorF32(value:F32, laneMask:Int):F32 {
    return Subgroup.shuffle(value, Subgroup.invocationId() ^ laneMask);
  }

  @:qdFunc
  public static function broadcastF32(value:F32, lane:Int):F32 {
    return Subgroup.broadcast(value, lane);
  }

  @:qdFunc
  public static function broadcastFirstF32(value:F32):F32 {
    return Subgroup.broadcast(value, 0);
  }

  @:qdFunc
  public static function shuffleF64(value:F64, lane:Int):F64 {
    return Subgroup.shuffle(value, lane);
  }

  @:qdFunc
  public static function shuffleXorF64(value:F64, laneMask:Int):F64 {
    return Subgroup.shuffle(value, Subgroup.invocationId() ^ laneMask);
  }

  @:qdFunc
  public static function broadcastFirstF64(value:F64):F64 {
    return Subgroup.broadcast(value, 0);
  }

  @:qdFunc
  public static function laneMaskLt():I32 {
    var lane:Int = Subgroup.invocationId();
    if (lane <= 0) return 0;
    return (1 << lane) - 1;
  }

  @:qdFunc
  public static function laneMaskLe():I32 {
    var lane:Int = Subgroup.invocationId();
    if (lane >= 31) return -1;
    return (1 << (lane + 1)) - 1;
  }

  @:qdFunc
  public static function laneMaskGt():I32 {
    return ~laneMaskLe();
  }

  @:qdFunc
  public static function laneMaskGe():I32 {
    return ~laneMaskLt();
  }

  @:qdFunc
  public static function activeMask():I32 {
    return Grid.activeMask();
  }

  @:qdFunc
  public static function elect():I32 {
    return Subgroup.elect();
  }

  @:qdFunc
  public static function sync():I32 {
    Subgroup.sync();
    return 0;
  }
}
