import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestKernelHelperRegistry {
  static inline var SECTION_FUNCTIONS = 8;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static function sectionOffset(bytes:hl.Bytes, kind:Int):Int {
    var sectionCount = u32(bytes, 8);
    for (i in 0...sectionCount) {
      var entry = 20 + i * 12;
      if (u32(bytes, entry) == kind) {
        return u32(bytes, entry + 4);
      }
    }
    throw 'descriptor section ${kind} is missing';
  }

  static function testDescriptorIncludesHelpers():Void {
    var descriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>, n:I32) -> {
      out[0] = KernelHelperChain.twiceAfterInc(n);
    }, {helpers: [KernelHelperMath, KernelHelperChain]});
    var functionsOffset = sectionOffset(descriptor, SECTION_FUNCTIONS);
    expectEq("helper_registry_descriptor_function_count", u32(descriptor, functionsOffset), 3);
  }

  public static function run():Void {
    testDescriptorIncludesHelpers();
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      var input:Tensor<I32> = null;
      var out:Tensor<I32> = null;
      try {
        input = new Tensor<I32>(ctx, [3]);
        out = new Tensor<I32>(ctx, [3]);
        input.fromArray([1, 2, 3]);
        k = Kernel.build(ctx, macro (a:Tensor<I32>, b:Tensor<I32>, n:I32) -> {
          for (i in 0...n) {
            b[i] = KernelHelperChain.twiceAfterInc(a[i]) + KernelHelperMath.triple(i);
          }
        }, {helpers: [KernelHelperMath, KernelHelperChain]});
        k.launch(input, out, 3);
        ctx.sync();
        expectEq("helper_registry_runtime0", out.read(0), 4);
        expectEq("helper_registry_runtime1", out.read(1), 9);
        expectEq("helper_registry_runtime2", out.read(2), 14);
      } catch (e:Dynamic) {
        if (out != null) out.close();
        if (input != null) input.close();
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      out.close();
      input.close();
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
