package quadrants;

abstract DiagnosticJson(Dynamic) from Dynamic to Dynamic {}

class Diagnostics {
  public static function health(ctx:Context):DiagnosticJson {
    return quadrants.compat.Diagnostics.health(ctx);
  }

  public static function dumpKernel(kernel:quadrants.kernel.QKernel):DiagnosticJson {
    if (kernel == null) {
      throw "Quadrants Diagnostics.dumpKernel requires a kernel";
    }
    return quadrants.compat.Diagnostics.kernelInfo(kernel.asKernel());
  }

  public static function dumpDescriptor(kernel:quadrants.kernel.QKernel):DiagnosticJson {
    if (kernel == null) {
      throw "Quadrants Diagnostics.dumpDescriptor requires a kernel";
    }
    return quadrants.compat.Diagnostics.descriptorDump(kernel.asKernel());
  }

  public static function dumpCapabilities(ctx:Context):DiagnosticJson {
    if (ctx == null) {
      throw "Quadrants Diagnostics.dumpCapabilities requires a Context";
    }
    return ctx.capabilities().toDynamic();
  }
}
