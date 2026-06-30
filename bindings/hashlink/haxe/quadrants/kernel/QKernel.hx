package quadrants.kernel;

import quadrants.KernelRaw;

interface QKernel {
  @:noCompletion public function raw():KernelRaw;
  public function name():String;
}
