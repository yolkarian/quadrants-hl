package quadrants;

class Block {
  public static function threadIdx():Int {
    return 0;
  }

  public static function sync():Void {}
  public static function barrier():Void {}
  public static function memFence():Void {}

  public static function barrierAnd(value:Int):Int {
    return value;
  }

  public static function barrierOr(value:Int):Int {
    return value;
  }

  public static function barrierCount(value:Int):Int {
    return value;
  }

  public static function warpSync(mask:Int):Void {}
}
