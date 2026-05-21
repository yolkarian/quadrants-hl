class Main {
  static function main():Void {
    TestArchApi.run();
    TestBindingApi.run();
    TestDescriptorSnapshot.run();
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
    TestReturn.run();
    TestField.run();
    TestQdFunc.run();
    TestNdrange.run();
    TestSimtApi.run();
    TestTapeApi.run();
    Sys.println("hashlink tests ok");
  }
}
