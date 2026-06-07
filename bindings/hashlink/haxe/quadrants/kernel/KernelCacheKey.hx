package quadrants.kernel;

import quadrants.flatten.SpecKey;

class KernelCacheKey {
  public static function from(kernelName:String, specKey:SpecKey):String {
    return kernelName + ":" + specKey.digest();
  }
}
