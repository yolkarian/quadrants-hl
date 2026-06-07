package quadrants.perf;

import quadrants.Types.Arch;

class PerfDispatchContext {
  public final arch:Arch;
  public final compileOptions:String;

  public function new(arch:Arch, compileOptions:String = "") {
    this.arch = arch;
    this.compileOptions = compileOptions == null ? "" : compileOptions;
  }
}
