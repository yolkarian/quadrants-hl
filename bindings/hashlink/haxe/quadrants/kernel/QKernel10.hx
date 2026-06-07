package quadrants.kernel;

class QKernel10<A, B, C, D, E, F, G, H, I, J, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->D->E->F->G->H->I->J->R;
  final launchOnFn:quadrants.Stream->A->B->C->D->E->F->G->H->I->J->R;
  final launchGraphFn:A->B->C->D->E->F->G->H->I->J->R;
  final wrapRaw:quadrants.KernelRaw->QKernel10<A, B, C, D, E, F, G, H, I, J, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->D->E->F->G->H->I->J->R, launchOnFn:quadrants.Stream->A->B->C->D->E->F->G->H->I->J->R, launchGraphFn:A->B->C->D->E->F->G->H->I->J->R, wrapRaw:quadrants.KernelRaw->QKernel10<A, B, C, D, E, F, G, H, I, J, R>) {
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

  public function launch(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    return launchFn(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    return launchOnFn(stream, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
  }

  public function launchGraph(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    return launchGraphFn(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
  }

  public function grad():QKernel10<A, B, C, D, E, F, G, H, I, J, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel10<A, B, C, D, E, F, G, H, I, J, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel10<A, B, C, D, E, F, G, H, I, J, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
}
