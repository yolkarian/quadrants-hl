import quadrants.Context;
import quadrants.Kernel;
import quadrants.Shared;
import quadrants.Template;
import quadrants.TemplateDType;
import quadrants.Tensor;
import quadrants.Types.DType;
import quadrants.Types.I32;
import quadrants.Types.F32;

class TestTemplateRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectFloat(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx:Context) {
      var kernels:Array<Kernel> = [];
      var intIn:Tensor<I32> = null;
      var intOut:Tensor<I32> = null;
      var floatIn:Tensor<F32> = null;
      var floatOut:Tensor<F32> = null;
      try {
        intIn = new Tensor<I32>(ctx, [1]);
        intOut = new Tensor<I32>(ctx, [1]);
        intIn.write(0, 4);
        var intKernel = Template.build(DType.I32, ctx, macro (input:Tensor<TemplateDType>, out:Tensor<TemplateDType>, delta:TemplateDType) -> {
          out[0] = input[0] + delta;
        });
        kernels.push(intKernel);
        intKernel.launch(intIn, intOut, 6);
        ctx.sync();
        expectEq('template_i32', intOut.read(0), 10);

        floatIn = new Tensor<F32>(ctx, [1]);
        floatOut = new Tensor<F32>(ctx, [1]);
        floatIn.write(0, 1.5);
        var floatKernel = Template.build(DType.F32, ctx, macro (input:Tensor<TemplateDType>, out:Tensor<TemplateDType>, scale:TemplateDType) -> {
          out[0] = input[0] * scale;
        });
        kernels.push(floatKernel);
        floatKernel.launch(floatIn, floatOut, 2.0);
        ctx.sync();
        expectFloat('template_f32', floatOut.read(0), 3.0);

        var sharedKernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
          var scratch = Shared.array(DType.I32, 2);
          scratch[0] = 7;
          var tile = Shared.tile16(DType.I32);
          tile[0] = scratch[0] + 2;
          out[0] = tile[0];
        });
        kernels.push(sharedKernel);
        sharedKernel.launch(intOut);
        ctx.sync();
        expectEq('shared_generic_dtype', intOut.read(0), 9);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        if (floatOut != null) floatOut.close();
        if (floatIn != null) floatIn.close();
        if (intOut != null) intOut.close();
        if (intIn != null) intIn.close();
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
      if (floatOut != null) floatOut.close();
      if (floatIn != null) floatIn.close();
      if (intOut != null) intOut.close();
      if (intIn != null) intIn.close();
    });
  }
}
