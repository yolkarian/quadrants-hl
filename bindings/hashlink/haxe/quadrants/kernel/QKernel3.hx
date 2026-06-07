package quadrants.kernel;

class QKernel3<A, B, C, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->R;
  final launchOnFn:quadrants.Stream->A->B->C->R;
  final launchGraphFn:A->B->C->R;
  final wrapRaw:quadrants.KernelRaw->QKernel3<A, B, C, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->R, launchOnFn:quadrants.Stream->A->B->C->R, launchGraphFn:A->B->C->R, wrapRaw:quadrants.KernelRaw->QKernel3<A, B, C, R>) {
    this.rawKernel = rawKernel;
    this.launchFn = launchFn;
    this.launchOnFn = launchOnFn;
    this.launchGraphFn = launchGraphFn;
    this.wrapRaw = wrapRaw;
  }

  public function raw():quadrants.KernelRaw {
    return rawKernel;
  }

  public function name():String {
    return rawKernel.kernelName();
  }

  public function launch(a0:A, a1:B, a2:C):R {
    return launchFn(a0, a1, a2);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C):R {
    return launchOnFn(stream, a0, a1, a2);
  }

  public function launchGraph(a0:A, a1:B, a2:C):R {
    return launchGraphFn(a0, a1, a2);
  }

  public function grad():QKernel3<A, B, C, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel3<A, B, C, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel3<A, B, C, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
}
