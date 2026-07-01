package quadrants;

typedef StructMemberSchema = {
  var name:String;
  var kind:String;
  var dtype:String;
  var lanes:Int;
  var rows:Int;
  var cols:Int;
  var offset:Int;
  var align:Int;
  var size:Int;
}

typedef StructSchema = {
  var version:Int;
  var name:String;
  var layoutPolicy:String;
  var sizeBytes:Int;
  var alignBytes:Int;
  var fields:Array<StructMemberSchema>;
}

