import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestQdFunc {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static function testDescriptorFunctionSignatures():Void {
    var descriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>, n:I32) -> {
      out[0] = helper(n);
    });
    var sectionCount = u32(descriptor, 8);
    var functionsOffset = -1;
    for (i in 0...sectionCount) {
      var entry = 20 + i * 12;
      if (u32(descriptor, entry) == 8) {
        functionsOffset = u32(descriptor, entry + 4);
      }
    }
    if (functionsOffset < 0) throw "qdFunc descriptor functions section is missing";
    expectEq("qdFunc_descriptor_function_count", u32(descriptor, functionsOffset), 3);
  }

  @:qdFunc
  static function squarePlusOne(x:Int):Int {
    return x * x + 1;
  }

  @:qdFunc
  static function helper(x:Int):Int {
    return squarePlusOne(x) + squarePlusOne(x - 1);
  }

  @:qdFunc
  static function folded(x:Int):Int {
    var acc:Int = 0;
    for (j in 0...3) {
      acc += x + j;
    }
    if (acc > 0) {
      acc = acc + 1;
    }
    return acc;
  }

  public static function run():Void {
    testDescriptorFunctionSignatures();
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var input = new Tensor<I32>(ctx, [3]);
        var out = new Tensor<I32>(ctx, [3]);
        input.fromArray([1, 2, 3]);
        k = Kernel.build(ctx, macro (a:Tensor<I32>, b:Tensor<I32>, n:I32) -> {
          for (i in 0...n) {
            var f:I32 = folded(a[i]);
            b[i] = helper(a[i]) + f;
          }
        });
        k.launch(input, out, 3);
        ctx.sync();
        expectEq("qdFunc0", out.read(0), 10);
        expectEq("qdFunc1", out.read(1), 17);
        expectEq("qdFunc2", out.read(2), 28);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
