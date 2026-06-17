package quadrants.descriptor;

import quadrants.Kernel;
import quadrants.compat.Diagnostics;
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

  public static function fromKernel(kernel:Kernel):Null<QdhlDescriptorMetadata> {
    var dump = Diagnostics.descriptorDump(kernel);
    return cast Reflect.field(dump, "descriptor");
  }
}
