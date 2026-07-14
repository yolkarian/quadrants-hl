package quadrants;

class Grid {
  public static function threadIdx():Int {
    return 0;
  }

  public static function activeMask():Int {
    return 0;
  }

  public static function vkGlobalThreadIdx():Int {
    return 0;
  }

  public static function matchAnySync(mask:quadrants.Types.U32, value:Int):quadrants.Types.U32 {
    return haxe.Int64.ofInt(0);
  }

  public static function matchAllSync(mask:quadrants.Types.U32, value:Int):quadrants.Types.U32 {
    return haxe.Int64.ofInt(0);
  }

  public static function memFence():Void {}
}
