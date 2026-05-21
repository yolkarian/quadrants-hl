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

  static function requestedArchNames():Array<String> {
    var value = Sys.getEnv("QD_HASHLINK_TEST_ARCHES");
    if (value == null || value.length == 0) {
      value = Sys.getEnv("QD_ARCH");
    }
    if (value == null || value.length == 0) {
      return [];
    }

    var result = [];
    for (part in value.toLowerCase().split(",")) {
      var name = StringTools.trim(part);
      if (name.length > 0) {
        result.push(name);
      }
    }
    return result;
  }

  static function isRequested(name:String, requested:Array<String>):Bool {
    return requested.indexOf("all") >= 0 || requested.indexOf(name) >= 0;
  }

  static function smokeBackend(name:String, arch:Arch, required:Bool):Void {
    var ctx:Context = null;
    var k:Kernel = null;

    try {
      ctx = new Context(arch);
    } catch (e:Dynamic) {
      if (required) {
        throw 'hashlink ${name} context failed: ${Std.string(e)}';
      }
      Sys.println('hashlink ${name} backend smoke skipped: ${Std.string(e)}');
      return;
    }

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
        expectEq('${name}_kernel[${i}]', output.read(i), (i + 1) * 3 + 1);
      }

      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) {
        k.close();
      }
      if (ctx != null) {
        ctx.close();
      }
      throw 'hashlink ${name} smoke failed: ${Std.string(e)}';
    }
  }

  static function smokeRequestedBackend(name:String, arch:Arch, requested:Array<String>):Void {
    if (isRequested(name, requested)) {
      smokeBackend(name, arch, true);
    }
  }

  public static function run():Void {
    testArchIds();
    smokeBackend("cpu", Arch.Cpu, true);

    // These device backends need matching native build flags and hardware/drivers,
    // so run them only when QD_HASHLINK_TEST_ARCHES or QD_ARCH selects them.
    var requested = requestedArchNames();
    smokeRequestedBackend("cuda", Arch.Cuda, requested);
    smokeRequestedBackend("vulkan", Arch.Vulkan, requested);
    smokeRequestedBackend("metal", Arch.Metal, requested);
    smokeRequestedBackend("amdgpu", Arch.Amdgpu, requested);
  }
}
