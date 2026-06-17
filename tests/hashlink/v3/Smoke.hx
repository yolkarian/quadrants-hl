import quadrants.Context;
import quadrants.Kernel;
import quadrants.Spec;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

@:build(quadrants.macro.QdArgs.build())
class V3SmokeState {
  public var out:Tensor<I32>;
  public var n:Int;

  public function new(ctx:Context, n:Int) {
    this.out = new Tensor<I32>(ctx, [n]);
    this.n = n;
  }

  @:kernel
  public function clear():Void {
    for (i in 0...n) {
      out[i] = 0;
    }
  }
}

class Smoke {
  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true});
    var x = new Tensor<I32>(ctx, [4]);
    var y = new Tensor<I32>(ctx, [4]);
    var add = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>, n:Spec<Int>) -> {
      for (i in 0...n) {
        out[i] = a[i] + 1;
      }
    }, {name: "v3_smoke_add"});
    for (i in 0...4) x.write(i, i);
    add.launch(x, y, Spec.of(4));
    ctx.sync();
    if (y.read(3) != 4) throw 'typed Kernel.build failed: ${y.read(3)}';

    var state = new V3SmokeState(ctx, 4);
    state.clear();
    ctx.sync();
    if (state.out.read(0) != 0) throw "QdArgs @:kernel failed";

    add.close();
    x.close();
    y.close();
    state.out.close();
    ctx.close();
    Sys.println("hashlink v3 smoke ok");
  }
}
