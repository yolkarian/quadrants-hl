package quadrants;

typedef VersionSnapshot = {
  var packageVersion:String;
  var expectedHdllAbi:Int;
  var expectedRuntimeAbi:Int;
  var descriptorVersion:Int;
  var descriptorMaxVersion:Int;
}

class VersionInfo {
  public static final PACKAGE_VERSION:String = quadrants.macro.VersionInfoBuild.packageVersion();
  public static inline var EXPECTED_HDLL_ABI = 3;
  public static inline var EXPECTED_RUNTIME_ABI = 1;
  public static inline var DESCRIPTOR_VERSION = 3;
  public static inline var DESCRIPTOR_MAX_VERSION = 3;

  public static function current():VersionSnapshot {
    return {
      packageVersion: PACKAGE_VERSION,
      expectedHdllAbi: EXPECTED_HDLL_ABI,
      expectedRuntimeAbi: EXPECTED_RUNTIME_ABI,
      descriptorVersion: DESCRIPTOR_VERSION,
      descriptorMaxVersion: DESCRIPTOR_MAX_VERSION,
    };
  }

  public static function checkNativeCompatibility():Void {
    Native.ensureConfigured();
    var hdllAbi = Native.hashlink_hdll_abi_version();
    if (hdllAbi != EXPECTED_HDLL_ABI) {
      throw 'Quadrants HashLink ABI mismatch: Haxe package expects ${EXPECTED_HDLL_ABI}, quadrants.hdll reports ${hdllAbi}';
    }
    var runtimeAbi = Native.hashlink_runtime_abi_version();
    if (runtimeAbi != EXPECTED_RUNTIME_ABI) {
      throw 'Quadrants runtime ABI mismatch: Haxe package expects ${EXPECTED_RUNTIME_ABI}, native runtime reports ${runtimeAbi}';
    }
    var descriptorVersion = Native.hashlink_descriptor_schema_version();
    if (descriptorVersion != DESCRIPTOR_VERSION) {
      throw 'Quadrants descriptor schema mismatch: Haxe package emits ${DESCRIPTOR_VERSION}, quadrants.hdll accepts ${descriptorVersion}';
    }
  }
}
