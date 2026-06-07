package quadrants.flatten;

class SpecKey {
  final parts:Array<String> = [];

  public function new() {}

  public function addTemplate(path:String, value:Dynamic):SpecKey {
    parts.push('template:${path}=' + Std.string(value));
    return this;
  }

  public function addResource(path:String, spec:String):SpecKey {
    parts.push('resource:${path}=' + spec);
    return this;
  }

  public function digest():String {
    return haxe.crypto.Md5.encode(parts.join("|"));
  }

  public function snapshot():Array<String> {
    return [for (part in parts) part];
  }
}
