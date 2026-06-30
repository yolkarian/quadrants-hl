package quadrants.descriptor;

import quadrants.descriptor.Descriptor.QdhlDescriptorMetadata;
import quadrants.kernel.QKernel;

typedef DescriptorV3Metadata = QdhlDescriptorMetadata;

class DescriptorV3 extends Descriptor {
  public static inline var SCHEMA_VERSION:Int = Descriptor.SCHEMA_VERSION;

  public static function fromKernel(kernel:QKernel):Null<DescriptorV3Metadata> {
    return Descriptor.fromKernel(kernel);
  }
}
