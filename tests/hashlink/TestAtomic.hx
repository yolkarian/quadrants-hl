import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

class TestAtomic {
  static inline final FETCH_ADD_N = 32;

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function closeContext(ctx:Context):Void {
    if (ctx != null) {
      try {
        ctx.close();
      } catch (_:Dynamic) {
      }
    }
  }

  static function closeKernel(k:Kernel):Void {
    if (k != null) {
      try {
        k.close();
      } catch (_:Dynamic) {
      }
    }
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

  static function runOnArch(name:String, arch:Arch, required:Bool):Void {
    var ctx:Context = null;
    var k:Kernel = null;

    try {
      ctx = new Context(arch);
    } catch (e:Dynamic) {
      if (required) {
        throw 'hashlink ${name} atomic context failed: ${Std.string(e)}';
      }
      Sys.println('hashlink ${name} atomic skipped: ${Std.string(e)}');
      return;
    }

    try {
      var out = ctx.ndarrayI32([1]);
      out.fillI32(0);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[0] += 1;
        }
      });
      k.launch(out, 32);
      ctx.sync();
      expectEq('${name}_atomic_add', out.readI32(0), 32);
      k.close();
      k = null;

      out.fillI32(40);
      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[0] -= 1;
        }
      });
      k.launch(out, 8);
      ctx.sync();
      expectEq('${name}_atomic_sub', out.readI32(0), 32);
      k.close();
      k = null;

      var counts = ctx.ndarrayI32([1]);
      var seen = ctx.ndarrayI32([FETCH_ADD_N]);
      counts.fillI32(0);
      seen.fillI32(0);
      k = Kernel.build(ctx, macro (counts, seen, n) -> {
        for (i in 0...n) {
          var slot = atomicAdd(counts[0], 1);
          if (slot >= 0 && slot < n) {
            seen[slot] += 1;
          }
        }
      });
      k.launch(counts, seen, FETCH_ADD_N);
      ctx.sync();
      expectEq('${name}_atomic_fetch_add_count', counts.readI32(0), FETCH_ADD_N);
      for (i in 0...FETCH_ADD_N) {
        expectEq('${name}_atomic_fetch_add_seen[${i}]', seen.readI32(i), 1);
      }
      k.close();
      k = null;

      ctx.close();
    } catch (e:Dynamic) {
      closeKernel(k);
      closeContext(ctx);
      throw e;
    }
  }

  public static function run():Void {
    runOnArch("cpu", Arch.Cpu, true);

    var requested = requestedArchNames();
    if (isRequested("cuda", requested)) {
      runOnArch("cuda", Arch.Cuda, true);
    }
  }
}
