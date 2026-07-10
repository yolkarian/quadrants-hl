package quadrants.ad;

import quadrants.Tape;
import quadrants.Tensor;
import quadrants.TensorRuntime;

typedef FwdModeSeed = haxe.extern.EitherType<Float, Array<Float>>;

class FwdMode {
  public static function run<TParam, TLoss>(param:Tensor<TParam>,
      loss:Tensor<TLoss>,
      seed:FwdModeSeed,
      body:Tape->Void,
      clearAfter:Bool = true):Tape {
    var parameterRuntime = requireTensor(param, "parameter");
    var lossRuntime = requireTensor(loss, "output");
    if (parameterRuntime.context != lossRuntime.context) {
      throw "Quadrants FwdMode.run parameter and output tensors must share a Context";
    }
    var seeds = seedValues(seed, parameterRuntime.elementCount());
    if (body == null) {
      throw "Quadrants FwdMode.run requires a body callback";
    }

    parameterRuntime.enableGradFlag(true);
    lossRuntime.enableGradFlag(true);
    var tape = Tape.run(body);
    tape.zeroRecordedDuals();
    Grad.zeroTensorDual(loss);
    seedParameterDual(param, seeds);
    tape.forward(clearAfter);
    return tape;
  }

  static function requireTensor<T>(value:Tensor<T>, role:String):TensorRuntime {
    if (value == null) {
      throw 'Quadrants FwdMode.run requires a ${role} tensor';
    }
    var runtime:TensorRuntime = cast value;
    runtime.requireAutodiffDType("dual");
    return runtime;
  }

  static function seedValues(seed:FwdModeSeed, elementCount:Int):Array<Float> {
    var raw:Dynamic = seed;
    if (raw == null) {
      throw "Quadrants FwdMode.run requires a seed";
    }
    if (Std.isOfType(raw, Array)) {
      var configured:Array<Dynamic> = cast raw;
      if (configured.length != elementCount) {
        throw 'Quadrants FwdMode.run seed length ${configured.length} must match parameter element count ${elementCount}';
      }
      return [for (value in configured) hostSeed(value)];
    }
    return [hostSeed(raw)];
  }

  static function seedParameterDual<T>(param:Tensor<T>, seeds:Array<Float>):Void {
    if (seeds.length == 1) {
      Grad.seedTensorDual(param, seeds[0]);
      return;
    }
    Grad.seedTensorDual(param, 0.0);
    var dual = param.lazyDual();
    for (i in 0...seeds.length) {
      Grad.writeTensorReal(dual, i, seeds[i], "FwdMode.run seed");
    }
  }

  static function hostSeed(value:Dynamic):Float {
    var seed:Float = cast value;
    if (Math.isNaN(seed) || Math.isNaN(seed - seed)) {
      throw "Quadrants FwdMode.run seed values must be finite";
    }
    return seed;
  }
}
