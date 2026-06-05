package quadrants.simt;

import quadrants.Subgroup;
import quadrants.Types.F32;
import quadrants.Types.I32;

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
  public static function broadcastI32(value:I32, lane:Int):I32 {
    return Subgroup.broadcast(value, lane);
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
  public static function broadcastF32(value:F32, lane:Int):F32 {
    return Subgroup.broadcast(value, lane);
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
