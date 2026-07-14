class Main {
  static function main():Void {
    V3RuntimeSemantic.run();
    ContextConfigSemantic.run();
    KernelMacroErgoSemantic.run();
    SparseNodeSemantic.run();
    SimtMathSemantic.run();
    Wave2OpsSemantic.run();
    Sys.println("hashlink v3 runtime semantic ok");
  }
}
