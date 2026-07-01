import haxe.Json;
import haxe.Timer;
import quadrants.Algorithms;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.algorithms.Scratch;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class BenchmarkMain {
  static function timeMs(body:Void->Void):Float {
    var start = Timer.stamp();
    body();
    return (Timer.stamp() - start) * 1000.0;
  }

  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu});
    var n = 1024;
    var x = new Tensor<I32>(ctx, [n]);
    var y = new Tensor<I32>(ctx, [n]);
    for (i in 0...n) x.write(i, i);
    var add = Kernel.build(ctx, macro (x:Tensor<I32>, y:Tensor<I32>, n:Int) -> {
      for (i in 0...n) y[i] = x[i] + 1;
    }, {name: "v3_bench_add"});
    var scratch = Scratch.create(ctx);
    scratch.reserve(4096);
    var reduced = new Tensor<I32>(ctx, [1]);

    add.launch(x, y, n);
    Algorithms.reduceAdd(ctx, y, reduced, scratch);
    ctx.sync();

    var addMs = timeMs(function() {
      for (_ in 0...20) add.launch(x, y, n);
      ctx.sync();
    });
    var reduceMs = timeMs(function() {
      for (_ in 0...20) Algorithms.reduceAdd(ctx, y, reduced, scratch);
      ctx.sync();
    });

    Sys.println(Json.stringify({
      benchmark: "hashlink-v3-cpu-semantic",
      iterations: 20,
      tensorElements: n,
      addMs: addMs,
      reduceAddMs: reduceMs,
      checksum: reduced.read(0),
    }));

    add.close();
    x.close();
    y.close();
    reduced.close();
    ctx.close();
  }
}
