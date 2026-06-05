package quadrants.ad;

import quadrants.Kernel;

class CustomGradient {
  public final forward:Kernel;
  public final backward:Kernel;
  public final forwardGrad:Null<Kernel>;
  public final validate:Null<Kernel>;

  public function new(forward:Kernel, backward:Kernel, ?forwardGrad:Kernel, ?validate:Kernel) {
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
}
