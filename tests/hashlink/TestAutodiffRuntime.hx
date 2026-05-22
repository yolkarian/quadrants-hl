import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tape;
import quadrants.Tensor;
import quadrants.Types.F32;

class TestAutodiffRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  static function enableGrad(tensor:Tensor<F32>):Tensor<F32> {
    tensor.enableGrad();
    return tensor;
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(name, ctx) {
      if (name == "vulkan" || name == "metal") {
        Sys.println('hashlink ${name} autodiff runtime skipped');
        return;
      }

      var kernels:Array<Kernel> = [];
      try {
        ctx.setAdstackConfig(true, 4096, 0);

        var x = enableGrad(new Tensor<F32>(ctx, [3]));
        var out = enableGrad(new Tensor<F32>(ctx, [3]));
        x.fromArray([2.0, 3.0, 4.0]);
        out.fill(0.0);

        var squareDirect = Kernel.build(ctx, macro (x:Tensor<F32>, out:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            out[i] = x[i] * x[i] + 1.0;
          }
        });
        kernels.push(squareDirect);
        squareDirect.launch(x, out, 3);
        ctx.sync();
        expectNear("autodiff_primal0", out.read(0), 5.0);
        expectNear("autodiff_primal1", out.read(1), 10.0);
        expectNear("autodiff_primal2", out.read(2), 17.0);

        var gradKernel = squareDirect.grad();
        kernels.push(gradKernel);
        x.grad.fill(0.0);
        out.grad.fill(1.0);
        gradKernel.launch(x, out, 3);
        ctx.sync();
        expectNear("autodiff_reverse_x0", x.grad.read(0), 4.0);
        expectNear("autodiff_reverse_x1", x.grad.read(1), 6.0);
        expectNear("autodiff_reverse_x2", x.grad.read(2), 8.0);

        var forwardKernel = squareDirect.forwardGrad();
        kernels.push(forwardKernel);
        x.dual.fromArray([1.0, 2.0, 3.0]);
        out.dual.fill(0.0);
        forwardKernel.launch(x, out, 3);
        ctx.sync();
        expectNear("autodiff_forward_out0", out.dual.read(0), 4.0);
        expectNear("autodiff_forward_out1", out.dual.read(1), 12.0);
        expectNear("autodiff_forward_out2", out.dual.read(2), 24.0);

        var validationKernel = squareDirect.validationKernel();
        kernels.push(validationKernel);
        out.fill(0.0);
        validationKernel.launch(x, out, 3);
        ctx.sync();
        expectNear("autodiff_validation_primal0", out.read(0), 5.0);
        expectNear("autodiff_validation_primal1", out.read(1), 10.0);
        expectNear("autodiff_validation_primal2", out.read(2), 17.0);

        var input = enableGrad(new Tensor<F32>(ctx, [3]));
        var mid = enableGrad(new Tensor<F32>(ctx, [3]));
        var loss = enableGrad(new Tensor<F32>(ctx, [1]));
        input.fromArray([1.0, 2.0, 3.0]);
        mid.fill(0.0);
        loss.fill(0.0);

        var square = Kernel.build(ctx, macro (input:Tensor<F32>, mid:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            mid[i] = input[i] * input[i];
          }
        });
        kernels.push(square);
        var reduce = Kernel.build(ctx, macro (mid:Tensor<F32>, loss:Tensor<F32>, n:Int) -> {
          for (i in 0...n) {
            loss[0] += mid[i];
          }
        });
        kernels.push(reduce);

        var backwardTape = new Tape();
        backwardTape.launch(square, input, mid, 3);
        backwardTape.launch(reduce, mid, loss, 3);
        ctx.sync();
        expectNear("tape_primal_loss", loss.read(0), 14.0);
        input.grad.fill(0.0);
        mid.grad.fill(0.0);
        loss.grad.fill(1.0);
        backwardTape.backward(true);
        ctx.sync();
        expectEq("tape_backward_clear", backwardTape.length, 0);
        expectNear("tape_backward_x0", input.grad.read(0), 2.0);
        expectNear("tape_backward_x1", input.grad.read(1), 4.0);
        expectNear("tape_backward_x2", input.grad.read(2), 6.0);

        var forwardTape = new Tape();
        mid.fill(0.0);
        loss.fill(0.0);
        input.dual.fromArray([1.0, 1.0, 1.0]);
        mid.dual.fill(0.0);
        loss.dual.fill(0.0);
        forwardTape.launch(square, input, mid, 3);
        forwardTape.launch(reduce, mid, loss, 3);
        ctx.sync();
        forwardTape.forward(true);
        ctx.sync();
        expectEq("tape_forward_clear", forwardTape.length, 0);
        expectNear("tape_forward_loss_dual", loss.dual.read(0), 12.0);

        var validateTape = new Tape();
        mid.fill(0.0);
        loss.fill(0.0);
        validateTape.launch(square, input, mid, 3);
        validateTape.launch(reduce, mid, loss, 3);
        ctx.sync();
        mid.fill(0.0);
        loss.fill(0.0);
        validateTape.validate(true);
        ctx.sync();
        expectEq("tape_validate_clear", validateTape.length, 0);
        expectNear("tape_validate_loss", loss.read(0), 14.0);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
    });
  }
}
