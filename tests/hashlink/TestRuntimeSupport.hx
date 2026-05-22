import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestRuntimeSupport {
  static var sharedContexts:Map<String, Context> = [];

  static function isKnownArchName(name:String):Bool {
    return name == "all" || name == "cpu" || name == "cuda" || name == "vulkan" || name == "metal" || name == "amdgpu";
  }

  public static function requestedArchNames():Array<String> {
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
        if (!isKnownArchName(name)) {
          throw 'Unknown HashLink test arch ${name}';
        }
        result.push(name);
      }
    }
    return result;
  }

  public static function isRequested(name:String, requested:Array<String>):Bool {
    return requested.indexOf("all") >= 0 || requested.indexOf(name) >= 0;
  }

  static function runRequestedArch(name:String, arch:Arch, requested:Array<String>, body:(String, Arch)->Void):Void {
    if (isRequested(name, requested)) {
      body(name, arch);
    }
  }

  static function acquireContext(name:String, arch:Arch, required:Bool):Context {
    var existing = sharedContexts.get(name);
    if (existing != null) {
      return existing;
    }

    var ctx:Context = null;
    try {
      ctx = new Context(arch);
    } catch (e:Dynamic) {
      if (required) {
        throw 'hashlink ${name} context failed: ${Std.string(e)}';
      }
      Sys.println('hashlink ${name} backend skipped: ${Std.string(e)}');
      return null;
    }
    sharedContexts.set(name, ctx);
    return ctx;
  }

  static function runOnContext(name:String, arch:Arch, required:Bool, body:(String, Context)->Void):Void {
    var ctx = acquireContext(name, arch, required);
    if (ctx == null) {
      return;
    }

    try {
      body(name, ctx);
    } catch (e:Dynamic) {
      closeSharedContexts();
      throw 'hashlink ${name} runtime failed: ${Std.string(e)}';
    }
  }

  public static function runEachRuntimeContext(body:(String, Context)->Void):Void {
    runEachRuntimeArch(function(name, arch) {
      runOnContext(name, arch, true, body);
    });
  }

  public static function runEachRuntimeArch(body:(String, Arch)->Void):Void {
    var requested = requestedArchNames();
    if (requested.length == 0) {
      body("cpu", Arch.Cpu);
      return;
    }
    if (isRequested("cpu", requested)) {
      body("cpu", Arch.Cpu);
    }
    runRequestedArch("cuda", Arch.Cuda, requested, body);
    runRequestedArch("vulkan", Arch.Vulkan, requested, body);
    runRequestedArch("metal", Arch.Metal, requested, body);
    runRequestedArch("amdgpu", Arch.Amdgpu, requested, body);
  }

  public static function runEachRequestedDeviceContext(body:(String, Context)->Void):Void {
    runEachRequestedDeviceArch(function(name, arch) {
      runOnContext(name, arch, true, body);
    });
  }

  public static function runEachRequestedDeviceArch(body:(String, Arch)->Void):Void {
    var requested = requestedArchNames();
    runRequestedArch("cuda", Arch.Cuda, requested, body);
    runRequestedArch("vulkan", Arch.Vulkan, requested, body);
    runRequestedArch("metal", Arch.Metal, requested, body);
    runRequestedArch("amdgpu", Arch.Amdgpu, requested, body);
  }

  public static function closeSharedContexts():Void {
    for (ctx in sharedContexts) {
      closeContext(ctx);
    }
    sharedContexts = [];
  }

  public static function closeContext(ctx:Context):Void {
    if (ctx != null) {
      try {
        ctx.close();
      } catch (_:Dynamic) {
      }
    }
  }

  public static function closeKernel(k:Kernel):Void {
    if (k != null) {
      try {
        k.close();
      } catch (_:Dynamic) {
      }
    }
  }

  public static function closeKernels(kernels:Array<Kernel>):Void {
    for (kernel in kernels) {
      closeKernel(kernel);
    }
  }
}
