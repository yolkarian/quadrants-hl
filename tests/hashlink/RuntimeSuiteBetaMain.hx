class RuntimeSuiteBetaMain {
  static function main():Void {
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
    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink runtime beta ok");
  }
}
