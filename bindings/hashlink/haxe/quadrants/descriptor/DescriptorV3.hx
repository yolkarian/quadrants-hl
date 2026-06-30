package quadrants.descriptor;

import quadrants.Kernel;
import quadrants.descriptor.Descriptor.QdhlDescriptorMetadata;

typedef DescriptorV3Metadata = QdhlDescriptorMetadata;

class DescriptorV3 extends Descriptor {
  public static inline var SCHEMA_VERSION:Int = Descriptor.SCHEMA_VERSION;

  public static function fromKernel(kernel:Kernel):Null<DescriptorV3Metadata> {
    return Descriptor.fromKernel(kernel);
  }
}
