package quadrants;

typedef VersionSnapshot = {
  var packageVersion:String;
  var expectedHdllAbi:Int;
  var expectedRuntimeAbi:Int;
  var descriptorVersion:Int;
  var descriptorMaxVersion:Int;
}

class VersionInfo {
  public static inline var PACKAGE_VERSION = "0.0.0";
  public static inline var EXPECTED_HDLL_ABI = 1;
  public static inline var EXPECTED_RUNTIME_ABI = 1;
  public static inline var DESCRIPTOR_VERSION = 2;
  public static inline var DESCRIPTOR_MAX_VERSION = 2;

  public static function current():VersionSnapshot {
    return {
      packageVersion: PACKAGE_VERSION,
      expectedHdllAbi: EXPECTED_HDLL_ABI,
      expectedRuntimeAbi: EXPECTED_RUNTIME_ABI,
      descriptorVersion: DESCRIPTOR_VERSION,
      descriptorMaxVersion: DESCRIPTOR_MAX_VERSION,
    };
  }
}
