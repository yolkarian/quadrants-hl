package quadrants;

class Subgroup {
  public static function size():Int {
    return 0;
  }

  public static function invocationId():Int {
    return 0;
  }

  public static function elect():Int {
    return 0;
  }

  public static function shuffle<T>(value:T, lane:Int):T {
    return value;
  }

  public static function shuffleDown<T>(value:T, delta:Int):T {
    return value;
  }

  public static function shuffleUp<T>(value:T, delta:Int):T {
    return value;
  }

  public static function broadcast<T>(value:T, lane:Int):T {
    return value;
  }

  public static function ballot(predicate:Int):quadrants.Types.U64 {
    return haxe.Int64.ofInt(0);
  }

  public static function sync():Void {}
  public static function barrier():Void {}
  public static function memFence():Void {}
}
