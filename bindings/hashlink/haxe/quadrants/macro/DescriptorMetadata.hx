package quadrants.macro;

#if macro
typedef QdhlParamMeta = {
  var path:String;
  var role:String;
  var kind:Int;
  var dtype:Int;
  var rank:Int;
}

typedef QdhlSpecMeta = {
  var path:String;
  var type:String;
  var value:String;
}

typedef QdhlMetaArgEntry = {
  var index:Int;
  var name:String;
  var sourcePath:String;
  var path:String;
  var role:String;
  var kind:String;
  var argKind:String;
  var typeId:Int;
  var access:String;
}

typedef QdhlMetaResourceEntry = {
  var path:String;
  var resourceKind:String;
  var kind:String;
  var typeId:Int;
  var rank:Int;
  var layout:String;
}
#end
