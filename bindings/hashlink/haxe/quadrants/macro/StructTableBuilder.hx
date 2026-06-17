package quadrants.macro;

#if macro
class StructTableBuilder {
  final entries:Array<Dynamic> = [];

  public function new() {}

  public function add(entry:Dynamic):Int {
    entries.push(entry);
    return entries.length;
  }

  public function build():Array<Dynamic> {
    return entries.copy();
  }
}
#end
