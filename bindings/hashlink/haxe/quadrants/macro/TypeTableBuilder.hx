package quadrants.macro;

#if macro
typedef TypeTableEntry = {
  var id:Int;
  var kind:String;
  var dtype:String;
  var rank:Int;
  @:optional var flags:Int;
  @:optional var structId:Int;
}

class TypeTableBuilder {
  final entries:Array<TypeTableEntry> = [];

  public function new() {}

  public function add(entry:TypeTableEntry):Int {
    entries.push(entry);
    return entries.length;
  }

  public function build():Array<TypeTableEntry> {
    return entries.copy();
  }
}
#end
