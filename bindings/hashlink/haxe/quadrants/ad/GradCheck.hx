package quadrants.ad;

import quadrants.FieldRuntime;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;

typedef GradCheckOptions = {
  ?epsilon:Float,
  ?absoluteTolerance:Float,
  ?relativeTolerance:Float,
  ?maxChecks:Int,
  ?maxMismatches:Int,
  ?resetLoss:Bool
}

typedef GradCheckMismatch = {
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
      throw 'Quadrants GradCheck failed for ${kernelName}: ${failureCount} mismatches across ${checked} checks; maxAbsError=${maxAbsError}, maxRelError=${maxRelError}';
    }
    return this;
  }
}

class GradCheck {
  static inline var DEFAULT_EPSILON:Float = 0.01;
  static inline var DEFAULT_ABSOLUTE_TOLERANCE:Float = 0.02;
  static inline var DEFAULT_RELATIVE_TOLERANCE:Float = 0.02;
  static inline var DEFAULT_MAX_MISMATCHES:Int = 16;
  static inline var RELATIVE_ERROR_FLOOR:Float = 1e-12;

  public static function checkTensorToScalar(kernel:Kernel,
      args:Array<Dynamic>,
      input:Tensor<F32>,
      loss:Tensor<F32>,
      ?options:GradCheckOptions):GradCheckResult {
    validate(kernel, args, input, loss);

    var elementCount = input.elementCount();
    if (elementCount <= 0) {
      throw "Quadrants GradCheck input tensor must contain at least one element";
    }

    var epsilon = optionFloat(options == null ? null : options.epsilon, DEFAULT_EPSILON, "epsilon");
    var absoluteTolerance = optionFloat(options == null ? null : options.absoluteTolerance, DEFAULT_ABSOLUTE_TOLERANCE, "absoluteTolerance");
    var relativeTolerance = optionFloat(options == null ? null : options.relativeTolerance, DEFAULT_RELATIVE_TOLERANCE, "relativeTolerance");
    var maxChecks = optionInt(options == null ? null : options.maxChecks, elementCount, "maxChecks");
    var maxMismatches = optionInt(options == null ? null : options.maxMismatches, DEFAULT_MAX_MISMATCHES, "maxMismatches");
    var resetLoss = options == null || options.resetLoss == null ? true : options.resetLoss;

    var indices = checkedIndices(elementCount, maxChecks);
    var originalInput = readInput(input);
    var initialLoss:Float = loss.read(0);

    restoreInput(input, originalInput);
    var analytic = analyticGradients(kernel, args, input, loss, indices, initialLoss, resetLoss);

    var mismatches:Array<GradCheckMismatch> = [];
    var failureCount = 0;
    var maxAbsError = 0.0;
    var maxRelError = 0.0;

    for (i in 0...indices.length) {
      var index = indices[i];
      var original = originalInput[index];
      var step = epsilon * Math.max(1.0, Math.abs(original));
      if (step <= 0.0) {
        step = epsilon;
      }

      input.write(index, original + step);
      prepareLoss(loss, initialLoss, resetLoss);
      kernel.launch(...args);
      input.context.sync();
      var plus:Float = loss.read(0);

      input.write(index, original - step);
      prepareLoss(loss, initialLoss, resetLoss);
      kernel.launch(...args);
      input.context.sync();
      var minus:Float = loss.read(0);

      input.write(index, original);

      var numeric = (plus - minus) / (2.0 * step);
      var analyticValue = analytic[i];
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
          mismatches.push({index: index, analytic: analyticValue, numeric: numeric, absError: absError, relError: relError});
        }
      }
    }

    restoreInput(input, originalInput);
    prepareLoss(loss, initialLoss, resetLoss);
    kernel.launch(...args);
    input.context.sync();

    return new GradCheckResult(failureCount == 0,
      indices.length,
      failureCount,
      maxAbsError,
      maxRelError,
      kernel.kernelName(),
      kernel.descriptorHash(),
      mismatches);
  }

  static function validate(kernel:Kernel, args:Array<Dynamic>, input:Tensor<F32>, loss:Tensor<F32>):Void {
    if (kernel == null) {
      throw "Quadrants GradCheck requires a kernel";
    }
    if (args == null) {
      throw "Quadrants GradCheck requires an argument array";
    }
    if (input == null) {
      throw "Quadrants GradCheck requires an input tensor";
    }
    if (loss == null) {
      throw "Quadrants GradCheck requires a scalar loss tensor";
    }
    if (input.context != loss.context) {
      throw "Quadrants GradCheck input and loss tensors must share a Context";
    }
    if (input.dtype != DType.F32 || loss.dtype != DType.F32) {
      throw "Quadrants GradCheck only supports F32 input and scalar loss tensors";
    }
    if (loss.elementCount() != 1) {
      throw "Quadrants GradCheck loss tensor must contain exactly one F32 element";
    }
    if (!containsArg(args, input)) {
      throw "Quadrants GradCheck args must include the checked input tensor";
    }
    if (!containsArg(args, loss)) {
      throw "Quadrants GradCheck args must include the scalar loss tensor";
    }
  }

  static function analyticGradients(kernel:Kernel,
      args:Array<Dynamic>,
      input:Tensor<F32>,
      loss:Tensor<F32>,
      indices:Array<Int>,
      initialLoss:Float,
      resetLoss:Bool):Array<Float> {
    input.enableGrad();
    loss.enableGrad();
    prepareLoss(loss, initialLoss, resetLoss);
    kernel.launch(...args);
    input.context.sync();

    zeroGradArgs(args);
    loss.grad.fill(1.0);

    var gradKernel = kernel.grad();
    try {
      gradKernel.launch(...args);
      input.context.sync();
    } catch (e:Dynamic) {
      gradKernel.close();
      throw e;
    }
    gradKernel.close();

    var gradients:Array<Float> = [];
    for (index in indices) {
      gradients.push(input.grad.read(index));
    }
    return gradients;
  }

  static function zeroGradArgs(args:Array<Dynamic>):Void {
    for (arg in args) {
      if (Std.isOfType(arg, TensorRuntime) || Std.isOfType(arg, FieldRuntime)) {
        Grad.zeroGrad(arg);
      }
    }
  }

  static function prepareLoss(loss:Tensor<F32>, initialLoss:Float, resetLoss:Bool):Void {
    if (resetLoss) {
      loss.fill(0.0);
    } else {
      loss.write(0, initialLoss);
    }
  }

  static function readInput(input:Tensor<F32>):Array<Float> {
    var values:Array<Float> = [];
    var count = input.elementCount();
    for (i in 0...count) {
      values.push(input.read(i));
    }
    return values;
  }

  static function restoreInput(input:Tensor<F32>, values:Array<Float>):Void {
    for (i in 0...values.length) {
      input.write(i, values[i]);
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

  static function containsArg(args:Array<Dynamic>, value:Dynamic):Bool {
    for (arg in args) {
      if (arg == value) {
        return true;
      }
    }
    return false;
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
