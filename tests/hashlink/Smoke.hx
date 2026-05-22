class Smoke {
  static function main():Void {
    TestBindingApi.run();
    TestArchApi.run();
    TestAtomic.run();
    TestRuntimeSupport.closeSharedContexts();
    Sys.println("hashlink smoke ok");
  }
}
