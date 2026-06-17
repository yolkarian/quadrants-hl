package quadrants.ad;

import quadrants.Kernel;
import quadrants.kernel.QKernel;

typedef CustomGradientOptions = {
  var backward:QKernel;
  @:optional var forwardGrad:QKernel;
  @:optional var validation:QKernel;
}

class CustomGradient {
  public final forward:Kernel;
  public final backward:Kernel;
  public final forwardGrad:Null<Kernel>;
  public final validate:Null<Kernel>;

  public function new(forward:QKernel, backward:QKernel, ?forwardGrad:QKernel, ?validate:QKernel) {
    if (forward == null) {
      throw "Quadrants custom gradient requires a forward kernel";
    }
    if (backward == null) {
      throw "Quadrants custom gradient requires a backward kernel";
    }
    this.forward = forward.asKernel();
    this.backward = backward.asKernel();
    this.forwardGrad = forwardGrad == null ? null : forwardGrad.asKernel();
    this.validate = validate == null ? null : validate.asKernel();
  }

  public static function register(forward:QKernel, options:CustomGradientOptions):CustomGradient {
    if (options == null) {
      throw "Quadrants CustomGradient.register requires options";
    }
    return new CustomGradient(forward, options.backward, options.forwardGrad, options.validation);
  }
}
