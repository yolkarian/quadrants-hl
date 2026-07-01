package quadrants.macro;

#if macro
typedef ResourceTableEntry = {
  var parameterIndex:Int;
  var name:String;
  var sourcePath:String;
  var resourceKind:String;
  var typeId:Int;
  var rank:Int;
  @:optional var layout:String;
  @:optional var flags:Int;
}

class ResourceTableBuilder {
  final entries:Array<ResourceTableEntry> = [];

  public function new() {}

  public function add(entry:ResourceTableEntry):Void {
    entries.push(entry);
  }

  public function build():Array<ResourceTableEntry> {
    return entries.copy();
  }
}
#end
