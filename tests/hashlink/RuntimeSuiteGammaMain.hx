class RuntimeSuiteGammaMain {
  static function main():Void {
    TestSharedSimtRuntime.run();
    TestKernelFeatureRuntime.run();
    TestProfilerRuntime.run();
    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink runtime gamma ok");
  }
}
