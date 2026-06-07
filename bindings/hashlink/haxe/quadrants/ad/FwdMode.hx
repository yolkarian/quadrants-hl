package quadrants.ad;

import quadrants.Tape;
import quadrants.Tensor;
import quadrants.Types.F32;

class FwdMode {
  public static function run(param:Tensor<F32>,
      loss:Tensor<F32>,
      seed:Float,
      body:Tape->Void,
      clearAfter:Bool = true):Tape {
    if (param == null) {
      throw "Quadrants FwdMode.run requires an F32 parameter tensor";
    }
    if (loss == null) {
      throw "Quadrants FwdMode.run requires an F32 output tensor";
    }
    if (param.context != loss.context) {
      throw "Quadrants FwdMode.run parameter and output tensors must share a Context";
    }
    if (body == null) {
      throw "Quadrants FwdMode.run requires a body callback";
    }

    param.enableGrad();
    loss.enableGrad();
    var tape = Tape.run(body);
    tape.zeroRecordedDuals();
    Grad.zeroTensorDual(loss);
    Grad.seedTensorDual(param, seed);
    tape.forward(clearAfter);
    return tape;
  }
}
