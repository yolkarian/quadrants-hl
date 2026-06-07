package quadrants;

import quadrants.Types.Arch;
import quadrants.Types.DType;

typedef FieldMirrorFallbackEvent = {
  var kernelName:String;
  var argIndex:Int;
  var reason:String;
  var bytesCopied:Int;
  var backend:Arch;
  var dtype:DType;
  var shape:Array<Int>;
  var snodeId:Int;
}
