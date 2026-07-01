package quadrants.kernel;

class QKernel6<A, B, C, D, E, F, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->D->E->F->R;
  final launchOnFn:quadrants.Stream->A->B->C->D->E->F->R;
  final launchGraphFn:A->B->C->D->E->F->R;
  final wrapRaw:quadrants.KernelRaw->QKernel6<A, B, C, D, E, F, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->D->E->F->R, launchOnFn:quadrants.Stream->A->B->C->D->E->F->R, launchGraphFn:A->B->C->D->E->F->R, wrapRaw:quadrants.KernelRaw->QKernel6<A, B, C, D, E, F, R>) {
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

  public function launch(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
    return launchFn(a0, a1, a2, a3, a4, a5);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
    return launchOnFn(stream, a0, a1, a2, a3, a4, a5);
  }

  public function launchGraph(a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
    return launchGraphFn(a0, a1, a2, a3, a4, a5);
  }

  public function grad():QKernel6<A, B, C, D, E, F, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel6<A, B, C, D, E, F, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel6<A, B, C, D, E, F, R> {
    return wrapRaw(rawKernel.validationKernel());
  }
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1, a2, a3, a4, a5);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
    var values:Array<Dynamic> = [a0, a1, a2, a3, a4, a5];
    return QKernelGraph.launchGraphDoWhile(rawKernel, control, values);
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
    tape.recordKernel(this, [a0, a1, a2, a3, a4, a5]);
    return launch(a0, a1, a2, a3, a4, a5);
  }

  public function launchTapeOn(stream:quadrants.Stream, tape:quadrants.Tape, a0:A, a1:B, a2:C, a3:D, a4:E, a5:F):R {
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
