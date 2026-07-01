import haxe.Json;
import haxe.Timer;
import quadrants.Context;
import quadrants.Graph;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class BackendRuntimeSemantic {
  static function archName(arch:Arch):String {
    return switch (arch) {
      case Arch.Cuda: "cuda";
      case Arch.Amdgpu: "amdgpu";
      case Arch.Vulkan: "vulkan";
      case Arch.Metal: "metal";
      default: "cpu";
    };
  }

  static function selectedArch():Arch {
    return switch (Sys.getEnv("QD_HASHLINK_TEST_ARCH")) {
      case "cuda": Arch.Cuda;
      case "amdgpu": Arch.Amdgpu;
      case value:
        throw 'QD_HASHLINK_TEST_ARCH must be cuda or amdgpu, got ${value}';
    };
  }

  static inline function eq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function main():Void {
    var arch = selectedArch();
    var backend = archName(arch);
    var ctx:Context = null;
    try {
      ctx = Context.create({arch: arch});
    } catch (e:Dynamic) {
      Sys.println(Json.stringify({test: "hashlink-backend-runtime-semantic", backend: backend, skipped: true, reason: Std.string(e)}));
      return;
    }

    var caps = ctx.capabilities();
    if (!caps.streams.events || !caps.streamParallel) {
      Sys.println(Json.stringify({
        test: "hashlink-backend-runtime-semantic",
        backend: backend,
        skipped: true,
        reason: "backend does not expose stream events/parallel streams",
      }));
      ctx.close();
      return;
    }

    var value = new Tensor<I32>(ctx, [1]);
    var out = new Tensor<I32>(ctx, [1]);
    var add = Kernel.build(ctx, macro (x:Tensor<I32>) -> {
      x[0] = x[0] + 1;
    }, {name: 'backend_${backend}_add'});
    var copy = Kernel.build(ctx, macro (x:Tensor<I32>, y:Tensor<I32>) -> {
      y[0] = x[0] + 100;
    }, {name: 'backend_${backend}_copy_after_event'});

    var streamA = ctx.createStream();
    var streamB = ctx.createStream();
    var eventStart = Timer.stamp();
    for (i in 0...8) {
      value.write(0, i);
      out.write(0, -1);
      ctx.sync();
      add.launchOn(streamA, value);
      var event = ctx.createEvent();
      event.record(streamA);
      streamB.wait(event);
      copy.launchOn(streamB, value, out);
      streamB.sync();
      ctx.sync();
      eq("backend_event_order_value", value.read(0), i + 1);
      eq("backend_event_order_out", out.read(0), i + 101);
      event.close();
    }
    var eventMs = (Timer.stamp() - eventStart) * 1000.0;

    var a = new Tensor<I32>(ctx, [1]);
    var b = new Tensor<I32>(ctx, [1]);
    a.write(0, 0);
    b.write(0, 0);
    ctx.sync();
    var parallelStart = Timer.stamp();
    Graph.parallel(ctx, [
      function() {
        for (_ in 0...16) add.launchOn(Graph.autoStream(), a);
      },
      function() {
        for (_ in 0...16) add.launchOn(Graph.autoStream(), b);
      },
    ]);
    ctx.sync();
    var parallelMs = (Timer.stamp() - parallelStart) * 1000.0;
    eq("backend_parallel_a", a.read(0), 16);
    eq("backend_parallel_b", b.read(0), 16);

    Sys.println(Json.stringify({benchmark: "backend.stream_event_ordering", backend: backend, iterations: 8, ms: eventMs}));
    Sys.println(Json.stringify({benchmark: "backend.graph_parallel", backend: backend, blocks: 2, launchesPerBlock: 16, ms: parallelMs}));

    streamA.close();
    streamB.close();
    add.close();
    copy.close();
    value.close();
    out.close();
    a.close();
    b.close();
    ctx.close();
  }
}
