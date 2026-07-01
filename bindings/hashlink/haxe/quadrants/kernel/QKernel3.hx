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
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C):R {
    while (control.read(0) != 0) {
      launchGraph(a0, a1, a2);
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>, a0:A, a1:B, a2:C):R {
    if (control == null) {
      throw "Quadrants graph do-while launch requires an I32 control Tensor";
    }
    if (!control.context.capabilities().graph.nativeDoWhile) {
      throw "Quadrants graph do-while launch requires capability graph.nativeDoWhile";
    }
    throw "Quadrants graph do-while native launch is not implemented for this backend";
  }

  public function launchTape(tape:quadrants.Tape, a0:A, a1:B, a2:C):R {
    tape.recordKernel(this, [a0, a1, a2]);
    return launch(a0, a1, a2);
  }

  public function launchTapeOn(stream:quadrants.Stream, tape:quadrants.Tape, a0:A, a1:B, a2:C):R {
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
