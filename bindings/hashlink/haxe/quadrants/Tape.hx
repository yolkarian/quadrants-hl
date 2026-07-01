package quadrants;

import quadrants.Types.F32;
import quadrants.ad.Grad;
import quadrants.ad.CustomGradient;
import quadrants.kernel.QKernel;

@:noCompletion abstract TapeArgs(Array<Dynamic>) from Array<Dynamic> to Array<Dynamic> {}

@:allow(quadrants.Tape)
private class TapeRecord {
  final rawKernel:KernelRaw;
  final custom:Null<CustomGradient>;
  final args:Array<Dynamic>;

  function new(rawKernel:KernelRaw, args:Array<Dynamic>, ?custom:CustomGradient) {
    if (rawKernel == null) {
      throw "Quadrants tape cannot record a null kernel";
    }
    this.rawKernel = rawKernel;
    this.custom = custom;
    this.args = [for (arg in args) arg];
  }

  static function fromKernel(kernel:QKernel, args:Array<Dynamic>):TapeRecord {
    if (kernel == null) {
      throw "Quadrants tape cannot record a null typed kernel";
    }
    return new TapeRecord(kernel.raw(), args);
  }

  static function fromCustom(custom:CustomGradient, args:Array<Dynamic>):TapeRecord {
    if (custom == null) {
      throw "Quadrants tape cannot record a null custom gradient";
    }
    return new TapeRecord(custom.forwardRaw(), args, custom);
  }

  function launchBackward():Void {
    if (custom != null) {
      custom.backwardRaw().launchDynamic(args);
      return;
    }
    launchDerived(rawKernel.grad());
  }

  function launchForward():Void {
    if (custom != null) {
      var forward = custom.forwardGradRaw();
      if (forward != null) {
        forward.launchDynamic(args);
        return;
      }
    }
    launchDerived(rawKernel.forwardGrad());
  }

  function launchValidate():Void {
    if (custom != null) {
      var validation = custom.validationRaw();
      if (validation != null) {
        validation.launchDynamic(args);
        return;
      }
    }
    launchDerived(rawKernel.validationKernel());
  }

  function launchDerived(replayKernel:KernelRaw):Void {
    try {
      replayKernel.launchDynamic(args);
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

  public static function withLoss(context:Context, loss:Tensor<F32>, body:Tape->Void, clearAfter:Bool = true):Tape {
    return withLossAndParams(context, loss, [], body, clearAfter);
  }

  public static function withLossAndParams(context:Context,
      loss:Tensor<F32>,
      params:Array<Tensor<F32>>,
      body:Tape->Void,
      clearAfter:Bool = true):Tape {
    requireLoss(context, loss);
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

  @:noCompletion public function recordKernel(kernel:QKernel, args:TapeArgs):Void {
    if (recording) {
      var custom = CustomGradient.registeredFor(kernel);
      if (custom != null) {
        records.push(TapeRecord.fromCustom(custom, (args : Array<Dynamic>)));
      } else {
        records.push(TapeRecord.fromKernel(kernel, (args : Array<Dynamic>)));
      }
    }
  }

  @:noCompletion public function recordCustom(custom:CustomGradient, args:TapeArgs):Void {
    if (recording) {
      records.push(TapeRecord.fromCustom(custom, (args : Array<Dynamic>)));
    }
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

  static function requireLoss(context:Context, loss:Tensor<F32>):Void {
    if (context == null) {
      throw "Quadrants Tape.withLoss requires a Context";
    }
    if (loss == null) {
      throw "Quadrants Tape.withLoss requires a scalar F32 loss tensor";
    }
    if (loss.context != context) {
      throw "Quadrants Tape.withLoss loss tensor must belong to the supplied Context";
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
