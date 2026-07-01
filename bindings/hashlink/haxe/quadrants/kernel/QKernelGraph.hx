package quadrants.kernel;

class QKernelGraph {
  public static function launchGraphDoWhile<R>(rawKernel:quadrants.KernelRaw,
      control:quadrants.Tensor<quadrants.Types.I32>,
      values:Array<Dynamic>):R {
    if (control == null) {
      throw "Quadrants graph do-while launch requires an I32 control Tensor";
    }
    if (!control.context.capabilities().graph.nativeDoWhile) {
      throw "Quadrants graph do-while launch requires capability graph.nativeDoWhile";
    }
    rawKernel.launchGraphDoWhileDynamic(controlArgId(control, values), values);
    return cast null;
  }

  static function controlArgId(control:quadrants.Tensor<quadrants.Types.I32>, values:Array<Dynamic>):Int {
    for (i in 0...values.length) {
      if (values[i] == control) {
        return i;
      }
    }
    throw "Quadrants graph_do_while control Tensor must be passed as a kernel argument";
  }
}
