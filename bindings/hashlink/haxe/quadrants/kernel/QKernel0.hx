package quadrants.kernel;

class QKernel0<R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:Void->R;
  final launchOnFn:quadrants.Stream->R;
  final launchGraphFn:Void->R;
  final wrapRaw:quadrants.KernelRaw->QKernel0<R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:Void->R, launchOnFn:quadrants.Stream->R, launchGraphFn:Void->R, wrapRaw:quadrants.KernelRaw->QKernel0<R>) {
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

  public function launch():R {
    return launchFn();
  }

  public function launchOn(stream:quadrants.Stream):R {
    return launchOnFn(stream);
  }

  public function launchGraph():R {
    return launchGraphFn();
  }

  public function grad():QKernel0<R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel0<R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel0<R> {
    return wrapRaw(rawKernel.validationKernel());
  }
  public function launchGraphWhile(control:quadrants.Tensor<quadrants.Types.I32>):R {
    while (control.read(0) != 0) {
      launchGraph();
      control.context.sync();
    }
    return cast null;
  }

  public function launchGraphDoWhile(control:quadrants.Tensor<quadrants.Types.I32>):R {
    do {
      launchGraph();
      control.context.sync();
    } while (control.read(0) != 0);
    return cast null;
  }

  public function launchTape(tape:quadrants.Tape):R {
    tape.recordKernel(this, []);
    return launch();
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
