package quadrants.kernel;

class QKernel12<A, B, C, D, E, F, G, H, I, J, K, L, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->D->E->F->G->H->I->J->K->L->R;
  final launchOnFn:quadrants.Stream->A->B->C->D->E->F->G->H->I->J->K->L->R;
  final launchGraphFn:A->B->C->D->E->F->G->H->I->J->K->L->R;
  final wrapRaw:quadrants.KernelRaw->QKernel12<A, B, C, D, E, F, G, H, I, J, K, L, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->D->E->F->G->H->I->J->K->L->R, launchOnFn:quadrants.Stream->A->B->C->D->E->F->G->H->I->J->K->L->R, launchGraphFn:A->B->C->D->E->F->G->H->I->J->K->L->R, wrapRaw:quadrants.KernelRaw->QKernel12<A, B, C, D, E, F, G, H, I, J, K, L, R>) {
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

  public function launch(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J, a10:K, a11:L):R {
    return launchFn(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J, a10:K, a11:L):R {
    return launchOnFn(stream, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
  }

  public function launchGraph(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J, a10:K, a11:L):R {
    return launchGraphFn(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
  }

  public function grad():QKernel12<A, B, C, D, E, F, G, H, I, J, K, L, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel12<A, B, C, D, E, F, G, H, I, J, K, L, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel12<A, B, C, D, E, F, G, H, I, J, K, L, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J, a10:K, a11:L):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J, a10:K, a11:L):R {
    do {
      launchGraph(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
      control.context.sync();
    } while (control.read(0) != 0);
    return cast null;
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J, a10:K, a11:L):R {
    tape.recordKernel(this, [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11]);
    return launch(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11);
  }

  public function descriptorHash():String {
    return rawKernel.descriptorHash();
  }

  public function descriptorLengthBytes():Int {
    return rawKernel.descriptorLengthBytes();
  }

  public function descriptorByteAt(index:Int):Int {
    return rawKernel.descriptorByteAt(index);
  }

  public function descriptor():quadrants.Kernel {
    return asKernel();
  }

  public function close():Void {
    rawKernel.close();
  }

  public function asKernel():quadrants.Kernel {
    return quadrants.Kernel.fromRaw(rawKernel);
  }

}
