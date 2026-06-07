package quadrants.kernel;

class ArgBuffer {
  public final values:Array<Dynamic>;

  public function new() {
    values = [];
  }

  public static function acquire():ArgBuffer {
    return new ArgBuffer();
  }

  public function addValue(value:Dynamic):Void {
    values.push(value);
  }

  public function toArray():Array<Dynamic> {
    return [for (value in values) value];
  }

  public function clear():Void {
    values.resize(0);
  }

  public function release():Void {
    clear();
  }
}
