package quadrants.ad;

import quadrants.Context;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.kernel.QKernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;

private class GradCheckTarget {
  public final name:String;
  public final value:Dynamic;
  public final context:Context;
  public final dtype:DType;
  public final elementCount:Int;
  final readValue:Int->Float;
  final writeValue:Int->Float->Void;
  final enableGradient:Void->Void;
  final readGradient:Int->Float;

  public function new(name:String,
      value:Dynamic,
      context:Context,
      dtype:DType,
      elementCount:Int,
      readValue:Int->Float,
      writeValue:Int->Float->Void,
      enableGradient:Void->Void,
      readGradient:Int->Float) {
    this.name = name;
    this.value = value;
    this.context = context;
    this.dtype = dtype;
    this.elementCount = elementCount;
    this.readValue = readValue;
    this.writeValue = writeValue;
    this.enableGradient = enableGradient;
    this.readGradient = readGradient;
  }

  public inline function read(index:Int):Float {
    return readValue(index);
  }

  public inline function write(index:Int, value:Float):Void {
    writeValue(index, value);
  }

  public inline function enableGrad():Void {
    enableGradient();
  }

  public inline function grad(index:Int):Float {
    return readGradient(index);
  }
}

private class GradCheckLoss {
  public final value:Dynamic;
  public final context:Context;
  public final dtype:DType;
  public final elementCount:Int;
  final readValue:Void->Float;
  final writeValue:Float->Void;
  final fillValue:Float->Void;
  final enableGradient:Void->Void;
  final seedGradient:Float->Void;

  public function new(value:Dynamic,
      context:Context,
      dtype:DType,
      elementCount:Int,
      readValue:Void->Float,
      writeValue:Float->Void,
      fillValue:Float->Void,
      enableGradient:Void->Void,
      seedGradient:Float->Void) {
    this.value = value;
    this.context = context;
    this.dtype = dtype;
    this.elementCount = elementCount;
    this.readValue = readValue;
    this.writeValue = writeValue;
    this.fillValue = fillValue;
    this.enableGradient = enableGradient;
    this.seedGradient = seedGradient;
  }

  public inline function read():Float {
    return readValue();
  }

  public inline function write(value:Float):Void {
    writeValue(value);
  }

  public inline function fill(value:Float):Void {
    fillValue(value);
  }

  public inline function enableGrad():Void {
    enableGradient();
  }

  public inline function seedGrad(value:Float):Void {
    seedGradient(value);
  }
}

typedef GradCheckOptions = {
  ?epsilon:Float,
  ?absoluteTolerance:Float,
  ?relativeTolerance:Float,
  ?maxChecks:Int,
  ?maxMismatches:Int,
  ?resetLoss:Bool
}

private typedef GradCheckPrecision = {
  var epsilon:Float;
  var absoluteTolerance:Float;
  var relativeTolerance:Float;
}

typedef GradCheckMismatch = {
  var parameter:Int;
  var parameterName:String;
  var index:Int;
  var analytic:Float;
  var numeric:Float;
  var absError:Float;
  var relError:Float;
}

class GradCheckResult {
  public final passed:Bool;
  public final checked:Int;
  public final failureCount:Int;
  public final maxAbsError:Float;
  public final maxRelError:Float;
  public final kernelName:String;
  public final descriptorHash:String;
  public final mismatches:Array<GradCheckMismatch>;

  public function new(passed:Bool,
      checked:Int,
      failureCount:Int,
      maxAbsError:Float,
      maxRelError:Float,
      kernelName:String,
      descriptorHash:String,
      mismatches:Array<GradCheckMismatch>) {
    this.passed = passed;
    this.checked = checked;
    this.failureCount = failureCount;
    this.maxAbsError = maxAbsError;
    this.maxRelError = maxRelError;
    this.kernelName = kernelName;
    this.descriptorHash = descriptorHash;
    this.mismatches = mismatches;
  }

  public function requirePass():GradCheckResult {
    if (!passed) {
      var detail = "";
      if (mismatches.length > 0) {
        var first = mismatches[0];
        detail = '; first mismatch ${first.parameterName}[${first.index}] analytic=${first.analytic}, numeric=${first.numeric}, absError=${first.absError}, relError=${first.relError}';
      }
      throw 'Quadrants GradCheck failed for ${kernelName}: ${failureCount} mismatches across ${checked} checks; maxAbsError=${maxAbsError}, maxRelError=${maxRelError}${detail}';
    }
    return this;
  }
}

class GradCheck {
  static inline var DEFAULT_EPSILON:Float = 0.01;
  static inline var DEFAULT_ABSOLUTE_TOLERANCE:Float = 0.02;
  static inline var DEFAULT_RELATIVE_TOLERANCE:Float = 0.02;
  static inline var DEFAULT_F64_EPSILON:Float = 1e-5;
  static inline var DEFAULT_F64_ABSOLUTE_TOLERANCE:Float = 1e-7;
  static inline var DEFAULT_F64_RELATIVE_TOLERANCE:Float = 1e-6;
  static inline var DEFAULT_MAX_MISMATCHES:Int = 16;
  static inline var RELATIVE_ERROR_FLOOR:Float = 1e-12;

  public static function checkTensorToScalar<TInput, TLoss>(kernel:QKernel,
      args:Array<Dynamic>,
      input:Tensor<TInput>,
      loss:Tensor<TLoss>,
      ?options:GradCheckOptions):GradCheckResult {
    return checkTargetsToScalar(kernel, args, [tensorTarget("input", input)], tensorLoss(loss), options);
  }

  public static function checkTensorsToScalar<TInput, TLoss>(kernel:QKernel,
      args:Array<Dynamic>,
      inputs:Array<Tensor<TInput>>,
      loss:Tensor<TLoss>,
      ?options:GradCheckOptions):GradCheckResult {
    return checkTargetsToScalar(kernel, args, tensorTargets(inputs), tensorLoss(loss), options);
  }

  public static function checkFieldToScalar<TInput, TLoss>(kernel:QKernel,
      args:Array<Dynamic>,
      input:Field<TInput>,
      loss:Tensor<TLoss>,
      ?options:GradCheckOptions):GradCheckResult {
    return checkTargetsToScalar(kernel, args, [fieldTarget("input", input)], tensorLoss(loss), options);
  }

  public static function checkFieldsToScalar<TInput, TLoss>(kernel:QKernel,
      args:Array<Dynamic>,
      inputs:Array<Field<TInput>>,
      loss:Tensor<TLoss>,
      ?options:GradCheckOptions):GradCheckResult {
    return checkTargetsToScalar(kernel, args, fieldTargets(inputs), tensorLoss(loss), options);
  }

  static function checkTargetsToScalar(kernel:QKernel,
      args:Array<Dynamic>,
      inputs:Array<GradCheckTarget>,
      loss:GradCheckLoss,
      ?options:GradCheckOptions):GradCheckResult {
    validate(kernel, args, inputs, loss);

    var precision = precisionDefaults(inputs, loss);
    if (precisionDType(inputs, loss) == DType.F16 && (options == null || options.epsilon == null)) {
      throw "Quadrants GradCheck F16 finite differences require an explicit epsilon representable by F16 host storage";
    }
    var epsilon = optionFloat(options == null ? null : options.epsilon, precision.epsilon, "epsilon");
    var absoluteTolerance = optionFloat(options == null ? null : options.absoluteTolerance, precision.absoluteTolerance, "absoluteTolerance");
    var relativeTolerance = optionFloat(options == null ? null : options.relativeTolerance, precision.relativeTolerance, "relativeTolerance");
    var configuredMaxChecks = options == null ? null : options.maxChecks;
    var maxMismatches = optionInt(options == null ? null : options.maxMismatches, DEFAULT_MAX_MISMATCHES, "maxMismatches");
    var resetLoss = options == null || options.resetLoss == null ? true : options.resetLoss;

    var indicesByInput:Array<Array<Int>> = [];
    var checked = 0;
    for (input in inputs) {
      var maxChecks = optionInt(configuredMaxChecks, input.elementCount, "maxChecks");
      var indices = checkedIndices(input.elementCount, maxChecks);
      indicesByInput.push(indices);
      checked += indices.length;
    }

    var originalInputs = readInputs(inputs);
    var initialLoss = loss.read();

    restoreInputs(inputs, originalInputs);
    var analytic = analyticGradients(kernel, args, inputs, loss, indicesByInput, initialLoss, resetLoss);

    var mismatches:Array<GradCheckMismatch> = [];
    var failureCount = 0;
    var maxAbsError = 0.0;
    var maxRelError = 0.0;

    for (parameter in 0...inputs.length) {
      var input = inputs[parameter];
      var indices = indicesByInput[parameter];
      var originalInput = originalInputs[parameter];
      for (i in 0...indices.length) {
        var index = indices[i];
        var original = originalInput[index];
        var step = epsilon * Math.max(1.0, Math.abs(original));
        if (step <= 0.0) {
          step = epsilon;
        }

        input.write(index, original + step);
        var plusInput = input.read(index);
        prepareLoss(loss, initialLoss, resetLoss);
        kernel.raw().launchDynamic(args);
        input.context.sync();
        var plus = loss.read();

        input.write(index, original - step);
        var minusInput = input.read(index);
        var sampledWidth = plusInput - minusInput;
        if (!(Math.abs(sampledWidth) > 0.0)) {
          input.write(index, original);
          throw 'Quadrants GradCheck ${input.name}[${index}] epsilon ${step} cannot produce distinct ${input.dtype} host values';
        }
        prepareLoss(loss, initialLoss, resetLoss);
        kernel.raw().launchDynamic(args);
        input.context.sync();
        var minus = loss.read();

        input.write(index, original);

        var numeric = (plus - minus) / sampledWidth;
        var analyticValue = analytic[parameter][i];
        var absError = Math.abs(analyticValue - numeric);
        var relDenom = Math.max(Math.max(Math.abs(analyticValue), Math.abs(numeric)), RELATIVE_ERROR_FLOOR);
        var relError = absError / relDenom;
        if (absError > maxAbsError) {
          maxAbsError = absError;
        }
        if (relError > maxRelError) {
          maxRelError = relError;
        }

        if (!valuesMatch(analyticValue, numeric, absError, relError, absoluteTolerance, relativeTolerance)) {
          failureCount++;
          if (mismatches.length < maxMismatches) {
            mismatches.push({parameter: parameter, parameterName: input.name, index: index, analytic: analyticValue, numeric: numeric, absError: absError, relError: relError});
          }
        }
      }
    }

    restoreInputs(inputs, originalInputs);
    prepareLoss(loss, initialLoss, resetLoss);
    kernel.raw().launchDynamic(args);
    loss.context.sync();

    return new GradCheckResult(failureCount == 0,
      checked,
      failureCount,
      maxAbsError,
      maxRelError,
      kernel.name(),
      kernel.raw().descriptorHash(),
      mismatches);
  }

  static function validate(kernel:QKernel, args:Array<Dynamic>, inputs:Array<GradCheckTarget>, loss:GradCheckLoss):Void {
    if (kernel == null) {
      throw "Quadrants GradCheck requires a kernel";
    }
    if (args == null) {
      throw "Quadrants GradCheck requires an argument array";
    }
    if (inputs == null || inputs.length == 0) {
      throw "Quadrants GradCheck requires at least one checked input";
    }
    if (loss == null) {
      throw "Quadrants GradCheck requires a scalar real loss";
    }
    if (loss.elementCount != 1) {
      throw "Quadrants GradCheck loss must contain exactly one element";
    }
    if (!containsArg(args, loss.value)) {
      throw "Quadrants GradCheck args must include the scalar loss";
    }
    for (input in inputs) {
      if (input == null) {
        throw "Quadrants GradCheck checked inputs cannot contain null";
      }
      if (input.context != loss.context) {
        throw "Quadrants GradCheck checked inputs and loss must share a Context";
      }
      if (input.elementCount <= 0) {
        throw 'Quadrants GradCheck input ${input.name} must contain at least one element';
      }
      if (!containsArg(args, input.value)) {
        throw 'Quadrants GradCheck args must include checked input ${input.name}';
      }
    }
  }

  static function analyticGradients(kernel:QKernel,
      args:Array<Dynamic>,
      inputs:Array<GradCheckTarget>,
      loss:GradCheckLoss,
      indicesByInput:Array<Array<Int>>,
      initialLoss:Float,
      resetLoss:Bool):Array<Array<Float>> {
    for (input in inputs) {
      input.enableGrad();
    }
    loss.enableGrad();
    prepareLoss(loss, initialLoss, resetLoss);
    kernel.raw().launchDynamic(args);
    loss.context.sync();

    zeroGradArgs(args);
    loss.seedGrad(1.0);

    var gradKernel = kernel.raw().grad();
    try {
      gradKernel.launchDynamic(args);
      loss.context.sync();
    } catch (e:Dynamic) {
      gradKernel.close();
      throw e;
    }
    gradKernel.close();

    var gradients:Array<Array<Float>> = [];
    for (parameter in 0...inputs.length) {
      var input = inputs[parameter];
      var values:Array<Float> = [];
      for (index in indicesByInput[parameter]) {
        values.push(input.grad(index));
      }
      gradients.push(values);
    }
    return gradients;
  }

  static function zeroGradArgs(args:Array<Dynamic>):Void {
    for (arg in args) {
      if ((Std.isOfType(arg, TensorRuntime) || Std.isOfType(arg, FieldRuntime)) && Grad.supportsAutodiff(arg)) {
        Grad.zeroGrad(arg);
      }
    }
  }

  static function prepareLoss(loss:GradCheckLoss, initialLoss:Float, resetLoss:Bool):Void {
    if (resetLoss) {
      loss.fill(0.0);
    } else {
      loss.write(initialLoss);
    }
  }

  static function readInputs(inputs:Array<GradCheckTarget>):Array<Array<Float>> {
    return [for (input in inputs) readInput(input)];
  }

  static function readInput(input:GradCheckTarget):Array<Float> {
    var values:Array<Float> = [];
    for (i in 0...input.elementCount) {
      values.push(input.read(i));
    }
    return values;
  }

  static function restoreInputs(inputs:Array<GradCheckTarget>, values:Array<Array<Float>>):Void {
    for (parameter in 0...inputs.length) {
      var input = inputs[parameter];
      var inputValues = values[parameter];
      for (i in 0...inputValues.length) {
        input.write(i, inputValues[i]);
      }
    }
  }

  static function checkedIndices(elementCount:Int, maxChecks:Int):Array<Int> {
    if (maxChecks <= 0) {
      throw "Quadrants GradCheck maxChecks must be positive";
    }
    if (maxChecks >= elementCount) {
      return [for (i in 0...elementCount) i];
    }
    if (maxChecks == 1) {
      return [0];
    }
    var result:Array<Int> = [];
    var previous = -1;
    for (i in 0...maxChecks) {
      var index = Std.int(Math.floor(i * (elementCount - 1) / (maxChecks - 1)));
      if (index != previous) {
        result.push(index);
        previous = index;
      }
    }
    return result;
  }

  static function tensorTargets<T>(inputs:Array<Tensor<T>>):Array<GradCheckTarget> {
    if (inputs == null || inputs.length == 0) {
      throw "Quadrants GradCheck requires at least one tensor input";
    }
    return [for (i in 0...inputs.length) tensorTarget('input${i}', inputs[i])];
  }

  static function fieldTargets<T>(inputs:Array<Field<T>>):Array<GradCheckTarget> {
    if (inputs == null || inputs.length == 0) {
      throw "Quadrants GradCheck requires at least one field input";
    }
    return [for (i in 0...inputs.length) fieldTarget('input${i}', inputs[i])];
  }

  static function tensorTarget<T>(name:String, input:Tensor<T>):GradCheckTarget {
    if (input == null) {
      throw "Quadrants GradCheck requires a real tensor input";
    }
    var runtime:TensorRuntime = cast input;
    runtime.requireAutodiffDType("grad");
    return new GradCheckTarget(name,
      input,
      runtime.context,
      runtime.dtype,
      runtime.elementCount(),
      function(index:Int):Float return Grad.readTensorReal(input, index, "GradCheck tensor input"),
      function(index:Int, value:Float):Void Grad.writeTensorReal(input, index, value, "GradCheck tensor input"),
      function():Void Grad.enableTensorGrad(input, "GradCheck tensor input"),
      function(index:Int):Float return Grad.readTensorReal(input.lazyGrad(), index, "GradCheck tensor gradient"));
  }

  static function fieldTarget<T>(name:String, input:Field<T>):GradCheckTarget {
    if (input == null) {
      throw "Quadrants GradCheck requires a real field input";
    }
    var runtime:FieldRuntime = cast input;
    runtime.requireAutodiffDType("grad");
    if (runtime.shape == null) {
      throw "Quadrants GradCheck field inputs must be placed";
    }
    return new GradCheckTarget(name,
      input,
      runtime.context,
      runtime.dtype,
      runtime.elementCount(),
      function(index:Int):Float return Grad.readFieldReal(input, index, "GradCheck field input"),
      function(index:Int, value:Float):Void Grad.writeFieldReal(input, index, value, "GradCheck field input"),
      function():Void Grad.enableFieldGrad(input, "GradCheck field input"),
      function(index:Int):Float return Grad.readFieldReal(input.lazyGrad(), index, "GradCheck field gradient"));
  }

  static function tensorLoss<T>(loss:Tensor<T>):GradCheckLoss {
    if (loss == null) {
      throw "Quadrants GradCheck requires a scalar real loss tensor";
    }
    var runtime:TensorRuntime = cast loss;
    runtime.requireAutodiffDType("grad");
    return new GradCheckLoss(loss,
      runtime.context,
      runtime.dtype,
      runtime.elementCount(),
      function():Float return Grad.readTensorReal(loss, 0, "GradCheck loss"),
      function(value:Float):Void Grad.writeTensorReal(loss, 0, value, "GradCheck loss"),
      function(value:Float):Void Grad.fillTensorReal(loss, value, "GradCheck loss"),
      function():Void Grad.enableTensorGrad(loss, "GradCheck loss"),
      function(value:Float):Void Grad.seedTensorGrad(loss, value));
  }

  static function containsArg(args:Array<Dynamic>, value:Dynamic):Bool {
    for (arg in args) {
      if (arg == value) {
        return true;
      }
    }
    return false;
  }

  static function precisionDefaults(inputs:Array<GradCheckTarget>, loss:GradCheckLoss):GradCheckPrecision {
    return switch (precisionDType(inputs, loss)) {
      case DType.F64:
        {epsilon: DEFAULT_F64_EPSILON, absoluteTolerance: DEFAULT_F64_ABSOLUTE_TOLERANCE, relativeTolerance: DEFAULT_F64_RELATIVE_TOLERANCE};
      case DType.F16, DType.F32:
        {epsilon: DEFAULT_EPSILON, absoluteTolerance: DEFAULT_ABSOLUTE_TOLERANCE, relativeTolerance: DEFAULT_RELATIVE_TOLERANCE};
      default:
        throw "Quadrants GradCheck requires real floating inputs and loss";
    };
  }

  static function precisionDType(inputs:Array<GradCheckTarget>, loss:GradCheckLoss):DType {
    var hasF32 = loss.dtype == DType.F32;
    if (loss.dtype == DType.F16) {
      return DType.F16;
    }
    for (input in inputs) {
      if (input.dtype == DType.F16) {
        return DType.F16;
      }
      if (input.dtype == DType.F32) {
        hasF32 = true;
      }
    }
    return hasF32 ? DType.F32 : DType.F64;
  }

  static function optionFloat(value:Null<Float>, fallback:Float, name:String):Float {
    var result:Float = value == null ? fallback : value;
    if (!(result > 0.0)) {
      throw 'Quadrants GradCheck ${name} must be positive';
    }
    return result;
  }

  static function optionInt(value:Null<Int>, fallback:Int, name:String):Int {
    var result:Int = value == null ? fallback : value;
    if (result <= 0) {
      throw 'Quadrants GradCheck ${name} must be positive';
    }
    return result;
  }

  static function valuesMatch(analytic:Float,
      numeric:Float,
      absError:Float,
      relError:Float,
      absoluteTolerance:Float,
      relativeTolerance:Float):Bool {
    if (!isFinite(analytic) || !isFinite(numeric) || !isFinite(absError) || !isFinite(relError)) {
      return false;
    }
    return absError <= absoluteTolerance || relError <= relativeTolerance;
  }

  static function isFinite(value:Float):Bool {
    return !Math.isNaN(value) && !Math.isNaN(value - value);
  }
}
