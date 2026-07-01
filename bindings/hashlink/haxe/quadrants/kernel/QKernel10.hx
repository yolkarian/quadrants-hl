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
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    var values:Array<Dynamic> = [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9];
    return QKernelGraph.launchGraphDoWhile(rawKernel, control, values);
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    tape.recordKernel(this, [a0, a1, a2, a3, a4, a5, a6, a7, a8, a9]);
    return launch(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
  }

  public function launchTapeOn(stream:quadrants.Stream, tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G, a7:H, a8:I, a9:J):R {
    throw "Quadrants Tape launch on explicit streams is not supported; launch typed tape kernels on the default stream and use stream kernels outside Tape";
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

  public function descriptor():quadrants.descriptor.Descriptor.QdhlDescriptorMetadata {
    return quadrants.descriptor.Descriptor.fromKernel(this);
  }

  public function close():Void {
    rawKernel.close();
  }

}
