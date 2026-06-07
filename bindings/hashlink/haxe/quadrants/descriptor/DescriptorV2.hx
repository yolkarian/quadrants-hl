package quadrants.descriptor;

import quadrants.Kernel;
import quadrants.compat.Diagnostics;
import quadrants.descriptor.ArgSchema.DescriptorArgEntry;
import quadrants.descriptor.TypeTable.DescriptorTypeEntry;

typedef DescriptorV2Metadata = {
  var version:Int;
  var kernelName:String;
  var types:Array<DescriptorTypeEntry>;
  var args:Array<DescriptorArgEntry>;
  var templates:Array<Dynamic>;
  var resources:Array<Dynamic>;
  var capabilities:Array<String>;
}

class DescriptorV2 {
  public static function fromKernel(kernel:Kernel):Null<DescriptorV2Metadata> {
    var dump = Diagnostics.descriptorDump(kernel);
    return cast Reflect.field(dump, "descriptorV2");
  }
}
