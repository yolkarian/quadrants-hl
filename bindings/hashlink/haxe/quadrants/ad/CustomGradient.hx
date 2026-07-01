package quadrants.ad;

import quadrants.KernelRaw;
import quadrants.descriptor.Descriptor;
import quadrants.kernel.QKernel;

typedef CustomGradientOptions = {
  var backward:QKernel;
  @:optional var forwardGrad:QKernel;
  @:optional var validation:QKernel;
}

class CustomGradient {
  static final registry:Map<String, CustomGradient> = new Map();

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
    validatePeerSchema(forward, backward, "backward");
    if (forwardGrad != null) {
      validatePeerSchema(forward, forwardGrad, "forwardGrad");
    }
    if (validate != null) {
      validatePeerSchema(forward, validate, "validation");
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
    var custom = new CustomGradient(forward, options.backward, options.forwardGrad, options.validation);
    registry.set(key(forward), custom);
    return custom;
  }

  @:noCompletion public static function registeredFor(forward:QKernel):Null<CustomGradient> {
    if (forward == null) {
      return null;
    }
    return registry.get(key(forward));
  }

  static function key(kernel:QKernel):String {
    var raw = kernel.raw();
    return kernel.name() + ":" + raw.descriptorHash() + ":" + raw.autodiffModeValue();
  }

  static function validatePeerSchema(forward:QKernel, peer:QKernel, role:String):Void {
    if (peer == null) {
      throw 'Quadrants custom gradient ${role} kernel is required';
    }
    var forwardMeta = Descriptor.fromKernel(forward);
    var peerMeta = Descriptor.fromKernel(peer);
    if (forwardMeta == null || peerMeta == null) {
      throw 'Quadrants custom gradient ${role} kernel is missing descriptor metadata';
    }
    if (forwardMeta.args.length != peerMeta.args.length) {
      throw 'Quadrants custom gradient ${role} kernel argument count mismatch';
    }
    for (i in 0...forwardMeta.args.length) {
      var expected = forwardMeta.args[i];
      var actual = peerMeta.args[i];
      if (expected.kind != actual.kind || expected.role != actual.role) {
        throw 'Quadrants custom gradient ${role} kernel argument ${i} kind mismatch';
      }
    }
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
