package quadrants.kernel;

class QKernel2<A, B, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->R;
  final launchOnFn:quadrants.Stream->A->B->R;
  final launchGraphFn:A->B->R;
  final wrapRaw:quadrants.KernelRaw->QKernel2<A, B, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->R, launchOnFn:quadrants.Stream->A->B->R, launchGraphFn:A->B->R, wrapRaw:quadrants.KernelRaw->QKernel2<A, B, R>) {
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

  public function launch(a0:A, a1:B):R {
    return launchFn(a0, a1);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B):R {
    return launchOnFn(stream, a0, a1);
  }

  public function launchGraph(a0:A, a1:B):R {
    return launchGraphFn(a0, a1);
  }

  public function grad():QKernel2<A, B, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel2<A, B, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel2<A, B, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
}
