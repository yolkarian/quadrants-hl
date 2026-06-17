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
