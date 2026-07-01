package quadrants.macro;

#if macro
typedef StructTableFieldEntry = {
  var name:String;
  var typeId:Int;
  var offset:Int;
  @:optional var align:Int;
  @:optional var size:Int;
}

typedef StructTableEntry = {
  var id:Int;
  var name:String;
  var sizeBytes:Int;
  var alignBytes:Int;
  var layoutPolicy:String;
  var fields:Array<StructTableFieldEntry>;
}

class StructTableBuilder {
  final entries:Array<StructTableEntry> = [];

  public function new() {}

  public function add(entry:StructTableEntry):Int {
    entries.push(entry);
    return entries.length;
  }

  public function build():Array<StructTableEntry> {
    return entries.copy();
  }
}
#end
