package quadrants.ad;

import quadrants.KernelRaw;
import quadrants.kernel.QKernel;

typedef CustomGradientOptions = {
  var backward:QKernel;
  @:optional var forwardGrad:QKernel;
  @:optional var validation:QKernel;
}

class CustomGradient {
  public final forward:QKernel;
  public final backward:QKernel;
  public final forwardGrad:Null<QKernel>;
  public final validate:Null<QKernel>;

  public function new(forward:QKernel, backward:QKernel, ?forwardGrad:QKernel, ?validate:QKernel) {
    if (forward == null) {
      throw "Quadrants custom gradient requires a forward kernel";
    }
    if (backward == null) {
      throw "Quadrants custom gradient requires a backward kernel";
    }
    this.forward = forward;
    this.backward = backward;
    this.forwardGrad = forwardGrad;
    this.validate = validate;
  }

  public static function register(forward:QKernel, options:CustomGradientOptions):CustomGradient {
    if (options == null) {
      throw "Quadrants CustomGradient.register requires options";
    }
    return new CustomGradient(forward, options.backward, options.forwardGrad, options.validation);
  }

  @:noCompletion public inline function forwardRaw():KernelRaw {
    return forward.raw();
  }

  @:noCompletion public inline function backwardRaw():KernelRaw {
    return backward.raw();
  }

  @:noCompletion public inline function forwardGradRaw():Null<KernelRaw> {
    return forwardGrad == null ? null : forwardGrad.raw();
  }

  @:noCompletion public inline function validationRaw():Null<KernelRaw> {
    return validate == null ? null : validate.raw();
  }
}
