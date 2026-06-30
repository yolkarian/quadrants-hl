package quadrants.kernel;

class ArgBuffer {
  static inline var MAX_POOL_SIZE = 16;
  static final pool:Array<ArgBuffer> = [];

  public final values:Array<Dynamic>;
  public final specs:Array<Dynamic>;
  var inPool:Bool = false;

  public function new() {
    values = [];
    specs = [];
  }

  public static function acquire():ArgBuffer {
    if (pool.length > 0) {
      var reused = pool.pop();
      reused.inPool = false;
      return reused;
    }
    return new ArgBuffer();
  }

  public function addValue(value:Dynamic):Void {
    values.push(value);
  }

  public function addSpec(value:Dynamic):Void {
    specs.push(value);
  }

  public function toArray():Array<Dynamic> {
    return [for (value in values) value];
  }

  public function specArray():Array<Dynamic> {
    return [for (value in specs) value];
  }

  public function clear():Void {
    values.resize(0);
    specs.resize(0);
  }

  public function release():Void {
    clear();
    if (!inPool && pool.length < MAX_POOL_SIZE) {
      inPool = true;
      pool.push(this);
    }
  }
}
