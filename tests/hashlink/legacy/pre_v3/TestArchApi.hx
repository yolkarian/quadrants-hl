import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestArchApi {
  static inline final N = 4;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function testArchIds():Void {
    expectEq("Arch.Cpu", Arch.Cpu, 0);
    expectEq("Arch.Cuda", Arch.Cuda, 1);
    expectEq("Arch.Vulkan", Arch.Vulkan, 2);
    expectEq("Arch.Metal", Arch.Metal, 3);
    expectEq("Arch.Amdgpu", Arch.Amdgpu, 4);
  }

  static function smokeBackend(ctx:Context):Void {
    var k:Kernel = null;
    try {
      var input = new Tensor<I32>(ctx, [N]);
      var output = new Tensor<I32>(ctx, [N]);
      for (i in 0...N) {
        input.write(i, i + 1);
        output.write(i, -1);
      }

      k = Kernel.build(ctx, macro (input, output) -> {
        for (i in 0...4) {
          output[i] = input[i] * 3 + 1;
        }
      });
      k.launch(input, output);
      ctx.sync();

      for (i in 0...N) {
        expectEq('kernel[${i}]', output.read(i), (i + 1) * 3 + 1);
      }
    } catch (e:Dynamic) {
      TestRuntimeSupport.closeKernel(k);
      throw e;
    }
    TestRuntimeSupport.closeKernel(k);
  }

  public static function run():Void {
    testArchIds();
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      smokeBackend(ctx);
    });
  }
}
