package quadrants.kernel;

class QKernel4<A, B, C, D, R> implements QKernel {
  final rawKernel:quadrants.KernelRaw;
  final launchFn:A->B->C->D->R;
  final launchOnFn:quadrants.Stream->A->B->C->D->R;
  final launchGraphFn:A->B->C->D->R;
  final wrapRaw:quadrants.KernelRaw->QKernel4<A, B, C, D, R>;

  public function new(rawKernel:quadrants.KernelRaw, launchFn:A->B->C->D->R, launchOnFn:quadrants.Stream->A->B->C->D->R, launchGraphFn:A->B->C->D->R, wrapRaw:quadrants.KernelRaw->QKernel4<A, B, C, D, R>) {
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

  public function launch(a0:A, a1:B, a2:C, a3:D):R {
    return launchFn(a0, a1, a2, a3);
  }

  public function launchOn(stream:quadrants.Stream, a0:A, a1:B, a2:C, a3:D):R {
    return launchOnFn(stream, a0, a1, a2, a3);
  }

  public function launchGraph(a0:A, a1:B, a2:C, a3:D):R {
    return launchGraphFn(a0, a1, a2, a3);
  }

  public function grad():QKernel4<A, B, C, D, R> {
    return wrapRaw(rawKernel.grad());
  }

  public function forwardGrad():QKernel4<A, B, C, D, R> {
    return wrapRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():QKernel4<A, B, C, D, R> {
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
