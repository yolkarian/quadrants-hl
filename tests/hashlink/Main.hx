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
    TestNdrange.run();
    TestGraphRuntime.run();
    TestAutodiffRuntime.run();
    TestSharedSimtRuntime.run();
    TestKernelFeatureRuntime.run();
    TestProfilerRuntime.run();

    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink tests ok");
  }
}
