package quadrants;

class Workgroup {
  public static function localInvocationId():Int {
    return 0;
  }

  public static function globalInvocationId():Int {
    return 0;
  }

  public static function sync():Void {}
  public static function barrier():Void {}
  public static function memFence():Void {}
  public static function gridMemFence():Void {}
}
