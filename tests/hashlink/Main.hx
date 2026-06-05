class Main {
  static function main():Void {
    TestBindingApi.run();
    TestDescriptorSnapshot.run();
    TestReturn.run();
    TestField.run();
    TestSimtApi.run();
    TestTapeApi.run();
    TestOfflineCacheRuntime.run();
    TestInteropImportRuntime.run();
    TestTemplateRuntime.run();
    TestStructRuntime.run();
    TestStreamEventRuntime.run();
    TestRuntimeFacade.run();

    TestArchApi.run();
    TestBasics.run();
    TestFor.run();
    TestIf.run();
    TestWhile.run();
    TestLoops.run();
    TestCompare.run();
    TestTypes.run();
    TestLocalReassignment.run();
    TestCast.run();
    TestUnaryOps.run();
    TestMathModule.run();
    TestNativeFunctions.run();
    TestMatrix.run();
    TestAtomic.run();
    TestFunction.run();
    TestQdFunc.run();
    TestKernelHelperRegistry.run();
    TestNdrange.run();
    TestGraphRuntime.run();
    TestAutodiffRuntime.run();
    TestSharedSimtRuntime.run();
    TestSimtHelpers.run();
    TestKernelFeatureRuntime.run();
    TestProfilerRuntime.run();
    TestAlgorithmsRuntime.run();
    TestAdCoverageDiagnosticsRuntime.run();
    TestPackedCompoundRuntime.run();
    TestBuilderControlDslRuntime.run();
    TestSparseProfilerBridgeRuntime.run();

    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink tests ok");
  }
}
