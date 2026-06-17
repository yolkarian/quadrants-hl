package quadrants.kernel;

import quadrants.KernelRaw;

interface QKernel {
  public function raw():KernelRaw;
  public function name():String;
  public function asKernel():quadrants.Kernel;
}
