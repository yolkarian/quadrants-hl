class Smoke {
  static function main():Void {
    TestArchApi.run();
    TestBindingApi.run();
    TestAtomic.run();
    Sys.println("hashlink smoke ok");
  }
}
