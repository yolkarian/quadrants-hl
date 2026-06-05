class RuntimeSuiteAlphaMain {
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
    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink runtime alpha ok");
  }
}
