package quadrants.kernel;

class QKernel7<A, B, C, D, E, F, G, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->D->E->F->G->R;
  final launchOnFn:quadrants.Stream->A->B->C->D->E->F->G->R;
  final launchGraphFn:A->B->C->D->E->F->G->R;
  final wrapRaw:quadrants.KernelRaw->QKernel7<A, B, C, D, E, F, G, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->D->E->F->G->R, launchOnFn:quadrants.Stream->A->B->C->D->E->F->G->R, launchGraphFn:A->B->C->D->E->F->G->R, wrapRaw:quadrants.KernelRaw->QKernel7<A, B, C, D, E, F, G, R>) {
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

  public function launch(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
    return launchFn(a0, a1, a2, a3, a4, a5, a6);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
    return launchOnFn(stream, a0, a1, a2, a3, a4, a5, a6);
  }

  public function launchGraph(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
    return launchGraphFn(a0, a1, a2, a3, a4, a5, a6);
  }

  public function grad():QKernel7<A, B, C, D, E, F, G, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel7<A, B, C, D, E, F, G, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel7<A, B, C, D, E, F, G, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1, a2, a3, a4, a5, a6);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
    var values:Array<Dynamic> = [a0, a1, a2, a3, a4, a5, a6];
    return QKernelGraph.launchGraphDoWhile(rawKernel, control, values);
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
    tape.recordKernel(this, [a0, a1, a2, a3, a4, a5, a6]);
    return launch(a0, a1, a2, a3, a4, a5, a6);
  }

  public function launchTapeOn(stream:quadrants.Stream, tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F, a6:G):R {
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
