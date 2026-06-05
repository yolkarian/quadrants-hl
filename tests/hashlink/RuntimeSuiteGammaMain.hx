class RuntimeSuiteGammaMain {
  static function main():Void {
    TestSharedSimtRuntime.run();
    TestSimtHelpers.run();
    TestKernelFeatureRuntime.run();
    TestProfilerRuntime.run();
    TestAlgorithmsRuntime.run();
    TestAdCoverageDiagnosticsRuntime.run();
    TestPackedCompoundRuntime.run();
    TestBuilderControlDslRuntime.run();
    TestSparseProfilerBridgeRuntime.run();
    TestCompoundParityRuntime.run();
    TestTypedDeepParityRuntime.run();
    TestReleaseReadinessRuntime.run();
    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink runtime gamma ok");
  }
}
