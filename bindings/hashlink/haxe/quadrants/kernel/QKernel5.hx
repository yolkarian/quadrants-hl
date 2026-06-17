package quadrants.kernel;

class QKernel5<A, B, C, D, E, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->D->E->R;
  final launchOnFn:quadrants.Stream->A->B->C->D->E->R;
  final launchGraphFn:A->B->C->D->E->R;
  final wrapRaw:quadrants.KernelRaw->QKernel5<A, B, C, D, E, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->D->E->R, launchOnFn:quadrants.Stream->A->B->C->D->E->R, launchGraphFn:A->B->C->D->E->R, wrapRaw:quadrants.KernelRaw->QKernel5<A, B, C, D, E, R>) {
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

  public function launch(a0:A, a1:B, a2:C, a3:D, a4:E):R {
    return launchFn(a0, a1, a2, a3, a4);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C, a3:D, a4:E):R {
    return launchOnFn(stream, a0, a1, a2, a3, a4);
  }

  public function launchGraph(a0:A, a1:B, a2:C, a3:D, a4:E):R {
    return launchGraphFn(a0, a1, a2, a3, a4);
  }

  public function grad():QKernel5<A, B, C, D, E, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel5<A, B, C, D, E, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel5<A, B, C, D, E, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1, a2, a3, a4);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E):R {
    do {
      launchGraph(a0, a1, a2, a3, a4);
      control.context.sync();
    } while (control.read(0) != 0);
    return cast null;
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E):R {
    tape.recordKernel(this, [a0, a1, a2, a3, a4]);
    return launch(a0, a1, a2, a3, a4);
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
