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
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B):R {
    var values:Array<Dynamic> = [a0, a1];
    return QKernelGraph.launchGraphDoWhile(rawKernel, control, values);
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B):R {
    tape.recordKernel(this, [a0, a1]);
    return launch(a0, a1);
  }

  public function launchTapeOn(stream:quadrants.Stream, tape:quadrants.Tape, a0:A, a1:B):R {
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
