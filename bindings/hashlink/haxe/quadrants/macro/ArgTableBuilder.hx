package quadrants.macro;

#if macro
typedef ArgTableEntry = {
  var parameterIndex:Int;
  var name:String;
  var sourcePath:String;
  var argKind:String;
  var kind:String;
  var typeId:Int;
  @:optional var role:String;
  @:optional var access:String;
  @:optional var flags:Int;
}

class ArgTableBuilder {
  final entries:Array<ArgTableEntry> = [];

  public function new() {}

  public function add(entry:ArgTableEntry):Void {
    entries.push(entry);
  }

  public function build():Array<ArgTableEntry> {
    return entries.copy();
  }
}
#end
