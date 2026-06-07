package quadrants;

import quadrants.Types.F32;
import quadrants.ad.Grad;
import quadrants.ad.CustomGradient;

private class TapeRecord {
  final kernel:Kernel;
  final custom:Null<CustomGradient>;
  public final args:Array<Dynamic>;

  public function new(kernel:Kernel, args:Array<Dynamic>, ?custom:CustomGradient) {
    if (kernel == null) {
      throw "Quadrants tape cannot record a null kernel";
    }
    this.kernel = kernel;
    this.custom = custom;
    this.args = [for (arg in args) arg];
  }

  public static function fromKernel(kernel:Kernel, args:Array<Dynamic>):TapeRecord {
    return new TapeRecord(kernel, args);
  }

  public static function fromCustom(custom:CustomGradient, args:Array<Dynamic>):TapeRecord {
    if (custom == null) {
      throw "Quadrants tape cannot record a null custom gradient";
    }
    return new TapeRecord(custom.forward, args, custom);
  }

  public function launchBackward():Void {
    if (custom != null) {
      launchBorrowed(custom.backward);
      return;
    }
    launchDerived(kernel.grad());
  }

  public function launchForward():Void {
    if (custom != null && custom.forwardGrad != null) {
      launchBorrowed(custom.forwardGrad);
      return;
    }
    launchDerived(kernel.forwardGrad());
  }

  public function launchValidate():Void {
    if (custom != null && custom.validate != null) {
      launchBorrowed(custom.validate);
      return;
    }
    launchDerived(kernel.validationKernel());
  }

  function launchBorrowed(replayKernel:Kernel):Void {
    replayKernel.launch(...args);
  }

  function launchDerived(replayKernel:Kernel):Void {
    try {
      replayKernel.launch(...args);
    } catch (e:Dynamic) {
      replayKernel.close();
      throw e;
    }
    replayKernel.close();
  }
}

class Tape {
  final records:Array<TapeRecord> = [];
  public var recording(default, null):Bool = true;

  public function new() {}

  public static function run(body:Tape->Void):Tape {
    if (body == null) {
      throw "Quadrants Tape.run requires a body callback";
    }
    var tape = new Tape();
    body(tape);
    return tape;
  }

  public static function runBackward(body:Tape->Void, clearAfter:Bool = false):Tape {
    var tape = run(body);
    tape.backward(clearAfter);
    return tape;
  }

  public static function runForward(body:Tape->Void, clearAfter:Bool = false):Tape {
    var tape = run(body);
    tape.forward(clearAfter);
    return tape;
  }

  public static function runValidate(body:Tape->Void, clearAfter:Bool = false):Tape {
    var tape = run(body);
    tape.validate(clearAfter);
    return tape;
  }

  public static function withLoss(loss:Tensor<F32>, body:Tape->Void, clearAfter:Bool = true):Tape {
    return withLossAndParams(loss, [], body, clearAfter);
  }

  public static function withLossAndParams(loss:Tensor<F32>,
      params:Array<Tensor<F32>>,
      body:Tape->Void,
      clearAfter:Bool = true):Tape {
    requireLoss(loss);
    if (params == null) {
      throw "Quadrants Tape.withLossAndParams requires a parameter array";
    }
    if (body == null) {
      throw "Quadrants Tape.withLoss requires a body callback";
    }

    loss.enableGrad();
    Grad.zeroTensorGrad(loss);
    zeroTensorParams(params, loss);

    var tape = new Tape();
    body(tape);
    tape.zeroRecordedGradients();
    zeroTensorParams(params, loss);
    Grad.seedTensorGrad(loss, 1.0);
    tape.backward(clearAfter);
    return tape;
  }

  public var length(get, never):Int;
  function get_length():Int return records.length;

  public function pause():Void {
    recording = false;
  }

  public function resume():Void {
    recording = true;
  }

  public function clear():Void {
    records.resize(0);
  }

  public function record(kernel:Kernel, args:Array<Dynamic>):Void {
    if (recording) {
      records.push(TapeRecord.fromKernel(kernel, args));
    }
  }

  public function recordCustom(custom:CustomGradient, args:Array<Dynamic>):Void {
    if (recording) {
      records.push(TapeRecord.fromCustom(custom, args));
    }
  }

  public function launch(kernel:Kernel, ...args:Dynamic):Void {
    kernel.launch(...args);
    record(kernel, args);
  }

  public function launchCustom(custom:CustomGradient, ...args:Dynamic):Void {
    if (custom == null) {
      throw "Quadrants tape cannot launch a null custom gradient";
    }
    custom.forward.launch(...args);
    recordCustom(custom, args);
  }

  public function backward(clearAfter:Bool = false):Void {
    var i = records.length;
    while (i > 0) {
      i--;
      records[i].launchBackward();
    }
    if (clearAfter) {
      clear();
    }
  }

  public function forward(clearAfter:Bool = false):Void {
    for (record in records) {
      record.launchForward();
    }
    if (clearAfter) {
      clear();
    }
  }

  public function validate(clearAfter:Bool = false):Void {
    for (record in records) {
      record.launchValidate();
    }
    if (clearAfter) {
      clear();
    }
  }
  function zeroRecordedGradients():Void {
    zeroRecordedPeers("grad");
  }

  @:allow(quadrants.ad.FwdMode)
  function zeroRecordedDuals():Void {
    zeroRecordedPeers("dual");
  }

  function zeroRecordedPeers(peerName:String):Void {
    for (record in records) {
      for (arg in record.args) {
        if (Std.isOfType(arg, TensorRuntime) || Std.isOfType(arg, FieldRuntime)) {
          if (peerName == "grad") {
            Grad.zeroGrad(arg);
          } else {
            Grad.zeroDual(arg);
          }
        }
      }
    }
  }

  static function requireLoss(loss:Tensor<F32>):Void {
    if (loss == null) {
      throw "Quadrants Tape.withLoss requires a scalar F32 loss tensor";
    }
    if (loss.elementCount() != 1) {
      throw "Quadrants Tape.withLoss loss tensor must contain exactly one element";
    }
  }

  static function zeroTensorParams(params:Array<Tensor<F32>>, loss:Tensor<F32>):Void {
    for (param in params) {
      if (param == null) {
        throw "Quadrants Tape.withLossAndParams parameters cannot contain null";
      }
      if (param.context != loss.context) {
        throw "Quadrants Tape.withLossAndParams parameters must share the loss Context";
      }
      param.enableGrad();
      Grad.zeroTensorGrad(param);
    }
  }
}
