package quadrants.macro;

#if macro
class ResourceTableBuilder {
  final entries:Array<Dynamic> = [];

  public function new() {}

  public function add(entry:Dynamic):Void {
    entries.push(entry);
  }

  public function build():Array<Dynamic> {
    return entries.copy();
  }
}
#end
