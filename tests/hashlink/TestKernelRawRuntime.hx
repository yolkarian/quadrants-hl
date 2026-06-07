import quadrants.Context;
import quadrants.ContextOptions;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.KernelRaw;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.kernel.ArgBuffer;

class TestKernelRawRuntime {
  static function expectEq(name:String, got:Dynamic, expected:Dynamic):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) {
      throw '${name}: expected true';
    }
  }

  static function runRawLaunch(ctx:Context):Void {
    var out = new Tensor<I32>(ctx, [1]);
    var raw:KernelRaw = null;
    try {
      raw = Kernel.buildRaw(ctx, macro (out:Tensor<I32>) -> {
        out[0] = out[0] + 1;
      });
      raw.launchDynamic([out]);
      expectEq("kernel_raw_launch_dynamic", out.read(0), 1);

      var buf = ArgBuffer.acquire();
      buf.addValue(out);
      raw.launchBuffer(buf);
      expectEq("kernel_raw_launch_buffer", out.read(0), 2);
      buf.release();

      expectTrue("kernel_raw_descriptor_hash", raw.descriptorHash().length == 8);
      raw.close();
      raw = null;
      out.close();
    } catch (e:Dynamic) {
      if (raw != null) {
        try raw.close() catch (_:Dynamic) {}
      }
      try out.close() catch (_:Dynamic) {}
      throw e;
    }
  }

  static function runFieldMirrorFallback(ctx:Context):Void {
    var field = new Field<I32>(ctx, [4]);
    var k:Kernel = null;
    try {
      field.fill(1);
      ctx.clearFieldMirrorFallbacks();
      k = Kernel.build(ctx, macro (values) -> {
        values[0] = values[0] + 1;
      });
      k.launch(field);
      ctx.sync();
      expectEq("field_mirror_fallback_value", field.read(0), 2);
      var events = ctx.fieldMirrorFallbacks();
      expectEq("field_mirror_fallback_count", events.length, 1);
      expectEq("field_mirror_fallback_arg", events[0].argIndex, 0);
      expectEq("field_mirror_fallback_snode", events[0].snodeId >= 0, true);
      expectTrue("field_mirror_fallback_bytes", events[0].bytesCopied > 0);
      expectEq("field_mirror_fallback_reason", events[0].reason, "descriptor parameter lowered as ndarray tensor mirror");
      k.close();
      k = null;
      field.close();
    } catch (e:Dynamic) {
      if (k != null) {
        try k.close() catch (_:Dynamic) {}
      }
      try field.close() catch (_:Dynamic) {}
      throw e;
    }
  }

  public static function run():Void {
    var ctx:Context = null;
    try {
      ctx = Context.fromOptions(ContextOptions.create().warnOnFieldMirrorFallback(false), Arch.Cpu);
      runRawLaunch(ctx);
      runFieldMirrorFallback(ctx);
      ctx.close();
    } catch (e:Dynamic) {
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
