package quadrants.kernel;

class QKernel1<A, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->R;
  final launchOnFn:quadrants.Stream->A->R;
  final launchGraphFn:A->R;
  final wrapRaw:quadrants.KernelRaw->QKernel1<A, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->R, launchOnFn:quadrants.Stream->A->R, launchGraphFn:A->R, wrapRaw:quadrants.KernelRaw->QKernel1<A, R>) {
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

  public function launch(a0:A):R {
    return launchFn(a0);
  }

  public function launchOn(stream:quadrants.Stream, a0:A):R {
    return launchOnFn(stream, a0);
  }

  public function launchGraph(a0:A):R {
    return launchGraphFn(a0);
  }

  public function grad():QKernel1<A, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel1<A, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel1<A, R> {
    return wrapRaw(rawKernel.validationKernel());
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
