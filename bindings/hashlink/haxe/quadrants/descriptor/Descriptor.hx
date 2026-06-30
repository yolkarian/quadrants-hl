package quadrants.descriptor;

import quadrants.compat.Diagnostics;
import quadrants.kernel.QKernel;
import quadrants.descriptor.ArgSchema.DescriptorArgEntry;
import quadrants.descriptor.TypeTable.DescriptorTypeEntry;

typedef QdhlDescriptorMetadata = {
  var version:Int;
  var kernelName:String;
  var types:Array<DescriptorTypeEntry>;
  var args:Array<DescriptorArgEntry>;
  var templates:Array<Dynamic>;
  var resources:Array<Dynamic>;
  var capabilities:Array<String>;
}

class Descriptor {
  public static inline var SCHEMA_VERSION:Int = 3;

  public static function fromKernel(kernel:QKernel):Null<QdhlDescriptorMetadata> {
    var dump = Diagnostics.descriptorDump(kernel.raw());
    return cast Reflect.field(dump, "descriptor");
  }
}
