import quadrants.Context;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.Tape;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.ad.CustomGradient;
import quadrants.ad.Grad;
import quadrants.ad.GradCheck;
import quadrants.compat.Diagnostics;
import quadrants.coverage.Coverage;
import sys.FileSystem;

class TestAdCoverageDiagnosticsRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  static function fieldInt(value:Dynamic, name:String):Int {
    return cast Reflect.field(value, name);
  }

  static function fieldBool(value:Dynamic, name:String):Bool {
    return cast Reflect.field(value, name);
  }

  static function enableGrad(tensor:Tensor<F32>):Tensor<F32> {
    tensor.enableGrad();
    return tensor;
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(name, ctx) {
      if (name == "vulkan" || name == "metal") {
        Sys.println('hashlink ${name} ad/diagnostics runtime skipped');
        return;
      }
      TestRuntimeSupport.closeSharedContexts();
      var localCtx:Context = null;
      var kernels:Array<Kernel> = [];
      var x:Tensor<F32> = null;
      var loss:Tensor<F32> = null;
      var aux:Tensor<F32> = null;
      var fieldInput:Field<F32> = null;
      var countOut:Tensor<I32> = null;
      try {
        localCtx = new Context(ctx.arch, true);
        localCtx.setAdstackConfig(true, 4096, 0);

        x = enableGrad(new Tensor<F32>(localCtx, [3]));
        loss = enableGrad(new Tensor<F32>(localCtx, [1]));
        aux = enableGrad(new Tensor<F32>(localCtx, [3]));
        countOut = new Tensor<I32>(localCtx, [1]);
        fieldInput = new Field<F32>(localCtx, [3]);
        x.fromArray([1.0, 2.0, 3.0]);
        loss.fill(0.0);
        aux.fill(0.0);
        fieldInput.fill(0.0);
        countOut.fill(0);

        var lossKernel = Kernel.build(localCtx, macro (x:Tensor<F32>, loss:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            loss[0] += x[i] * x[i];
          }
        });
        kernels.push(lossKernel);

        Coverage.enable(true);
        var coverageKernel = Kernel.build(localCtx, macro (out:Tensor<I32>) -> {
          out[0] = 7;
        });
        kernels.push(coverageKernel);
        coverageKernel.launch(countOut);
        localCtx.sync();
        var coverageSnapshot = Coverage.snapshot();
        if (coverageSnapshot.length != 1) throw "coverage_snapshot_count";
        expectEq("coverage_build_count", fieldInt(coverageSnapshot[0], "builds"), 1);
        expectEq("coverage_launch_count", fieldInt(coverageSnapshot[0], "launches"), 1);
        if (fieldInt(coverageSnapshot[0], "probeCount") <= 0) throw "coverage_probe_count";
        expectEq("coverage_covered_probes", fieldInt(coverageSnapshot[0], "coveredProbes"), fieldInt(coverageSnapshot[0], "probeCount"));
        var coveragePath = "build/hashlink-phase35-coverage.json";
        Coverage.flush(coveragePath);
        if (!FileSystem.exists(coveragePath)) throw "coverage_artifact_missing";
        Coverage.reset();
        expectEq("coverage_reset_empty", Coverage.snapshot().length, 0);
        Coverage.disable();

        var info = Diagnostics.kernelInfo(lossKernel);
        if (Reflect.field(info, "descriptorHash") == null) throw "diagnostics_kernel_hash";
        var dump = Diagnostics.descriptorDump(lossKernel);
        if (fieldInt(dump, "version") != 2) throw "diagnostics_descriptor_version";
        var valueInfo = Diagnostics.valueInfo(x);
        if (Reflect.field(valueInfo, "kind") != "tensor") throw "diagnostics_value_kind";
        var health = Diagnostics.health(localCtx);
        if (!fieldBool(health, "healthy")) throw "diagnostics_health";
        Diagnostics.assertHealthy(localCtx);

        var backwardTape = Tape.runBackward(function(tape) {
          loss.fill(0.0);
          tape.launch(lossKernel, x, loss, 3);
          localCtx.sync();
          Grad.clearAllGradients(x, loss);
          loss.grad.fill(1.0);
        }, true);
        localCtx.sync();
        expectEq("tape_run_backward_clear", backwardTape.length, 0);
        expectNear("tape_run_backward_x0", x.grad.read(0), 2.0);
        expectNear("tape_run_backward_x1", x.grad.read(1), 4.0);
        expectNear("tape_run_backward_x2", x.grad.read(2), 6.0);

        x.dual.fromArray([1.0, 1.0, 1.0]);
        loss.dual.fill(0.0);
        var forwardTape = Tape.runForward(function(tape) {
          loss.fill(0.0);
          tape.launch(lossKernel, x, loss, 3);
        }, true);
        localCtx.sync();
        expectEq("tape_run_forward_clear", forwardTape.length, 0);
        expectNear("tape_run_forward_loss", loss.dual.read(0), 12.0);

        loss.fill(0.0);
        var validateTape = Tape.runValidate(function(tape) {
          tape.launch(lossKernel, x, loss, 3);
          localCtx.sync();
          loss.fill(0.0);
        }, true);
        localCtx.sync();
        expectEq("tape_run_validate_clear", validateTape.length, 0);
        expectNear("tape_run_validate_loss", loss.read(0), 14.0);

        Grad.zeroGrad(x);
        expectNear("grad_zero_x0", x.grad.read(0), 0.0);
        x.dual.fill(3.0);
        Grad.zeroDual(x);
        expectNear("dual_zero_x0", x.dual.read(0), 0.0);

        x.fromArray([1.0, 2.0, 3.0]);
        loss.fill(0.0);
        var gradCheck = GradCheck.checkTensorToScalar(lossKernel, [x, loss, 3], x, loss, {epsilon: 0.01, absoluteTolerance: 0.03, relativeTolerance: 0.03});
        gradCheck.requirePass();
        expectEq("gradcheck_checked", gradCheck.checked, 3);

        aux.fromArray([4.0, 5.0, 6.0]);
        x.fromArray([1.0, 2.0, 3.0]);
        loss.fill(0.0);
        var multiLossKernel = Kernel.build(localCtx, macro (x:Tensor<F32>, y:Tensor<F32>, loss:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            loss[0] += x[i] * x[i] + x[i] * y[i];
          }
        });
        kernels.push(multiLossKernel);
        var multiGradCheck = GradCheck.checkTensorsToScalar(multiLossKernel, [x, aux, loss, 3], [x, aux], loss, {epsilon: 0.01, absoluteTolerance: 0.04, relativeTolerance: 0.04});
        multiGradCheck.requirePass();
        expectEq("gradcheck_multi_checked", multiGradCheck.checked, 6);

        fieldInput.fromArray([1.0, 2.0, 3.0]);
        loss.fill(0.0);
        var fieldLossKernel = Kernel.build(localCtx, macro (fieldInput:Field<F32>, loss:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            loss[0] += fieldInput[i] * fieldInput[i];
          }
        });
        kernels.push(fieldLossKernel);
        var fieldGradCheck = GradCheck.checkFieldToScalar(fieldLossKernel, [fieldInput, loss, 3], fieldInput, loss, {epsilon: 0.01, absoluteTolerance: 0.03, relativeTolerance: 0.03});
        fieldGradCheck.requirePass();
        expectEq("gradcheck_field_checked", fieldGradCheck.checked, 3);

        x.fromArray([0.0, 2.0, 3.0]);
        loss.fill(0.0);
        var kinkKernel = Kernel.build(localCtx, macro (x:Tensor<F32>, loss:Tensor<F32>) -> {
          if (x[0] > 0.0) {
            loss[0] += x[0];
          } else {
            loss[0] += 2.0 * x[0];
          }
        });
        kernels.push(kinkKernel);
        var failingGradCheck = GradCheck.checkTensorToScalar(kinkKernel, [x, loss], x, loss, {epsilon: 0.01, absoluteTolerance: 0.001, relativeTolerance: 0.001, maxChecks: 1});
        if (failingGradCheck.passed) throw "gradcheck_failure_expected";
        expectEq("gradcheck_failure_count", failingGradCheck.failureCount, 1);
        expectEq("gradcheck_failure_mismatch_count", failingGradCheck.mismatches.length, 1);
        if (failingGradCheck.mismatches[0].parameterName != "input") throw "gradcheck_failure_parameter_name";
        expectEq("gradcheck_failure_index", failingGradCheck.mismatches[0].index, 0);
        var requirePassFailed = false;
        try {
          failingGradCheck.requirePass();
        } catch (e:Dynamic) {
          requirePassFailed = Std.string(e).indexOf("first mismatch input[0]") >= 0;
        }
        if (!requirePassFailed) throw "gradcheck_failure_require_pass";

        var customForward = Kernel.build(localCtx, macro (x:Tensor<F32>, out:Tensor<F32>, xGrad:Tensor<F32>, outGrad:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            out[i] = x[i] * x[i];
          }
          if (n < 0) {
            xGrad[0] = outGrad[0];
          }
        });
        kernels.push(customForward);
        var customBackward = Kernel.build(localCtx, macro (x:Tensor<F32>, out:Tensor<F32>, xGrad:Tensor<F32>, outGrad:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            xGrad[i] += 2.0 * x[i] * outGrad[i];
          }
          if (n < 0) {
            out[0] = out[0];
          }
        });
        kernels.push(customBackward);
        var custom = new CustomGradient(customForward, customBackward);
        x.fromArray([2.0, 3.0, 4.0]);
        aux.fill(0.0);
        x.grad.fill(0.0);
        aux.grad.fill(1.0);
        var customTape = new Tape();
        customTape.launchCustom(custom, x, aux, x.grad, aux.grad, 3);
        localCtx.sync();
        customTape.backward(true);
        localCtx.sync();
        expectEq("custom_tape_clear", customTape.length, 0);
        expectNear("custom_backward_x0", x.grad.read(0), 4.0);
        expectNear("custom_backward_x1", x.grad.read(1), 6.0);
        expectNear("custom_backward_x2", x.grad.read(2), 8.0);
      } catch (e:Dynamic) {
        if (countOut != null) countOut.close();
        if (fieldInput != null) fieldInput.close();
        if (aux != null) aux.close();
        if (loss != null) loss.close();
        if (x != null) x.close();
        TestRuntimeSupport.closeKernels(kernels);
        TestRuntimeSupport.closeContext(localCtx);
        Coverage.disable();
        throw e;
      }
      countOut.close();
      fieldInput.close();
      aux.close();
      loss.close();
      x.close();
      TestRuntimeSupport.closeKernels(kernels);
      TestRuntimeSupport.closeContext(localCtx);
      Coverage.disable();
    });
  }
}
