import quadrants.Context;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.flatten.DataOriented;
import quadrants.flatten.Flattened;

@:rtti
@:qdFlatten
class FlatState {
  public final x:Tensor<I32>;
  @:param public final bias:I32;
  @:template public final n:I32;

  public function new(x:Tensor<I32>, bias:I32, n:I32) {
    this.x = x;
    this.bias = bias;
    this.n = n;
  }
}

@:rtti
@:qdFlatten
class NestedFlatState {
  public final inner:FlatState;

  public function new(inner:FlatState) {
    this.inner = inner;
  }
}

@:rtti
@:qdDataOriented("ctx")
class ParticleSim extends DataOriented {
  public final ctx:Context;
  public final x:Tensor<I32>;
  @:template public final n:I32;

  public function new(ctx:Context, x:Tensor<I32>, n:I32) {
    this.ctx = ctx;
    this.x = x;
    this.n = n;
  }

  @:kernel
  public function add(delta:I32):Void {
    for (i in 0...n) {
      x[i] = x[i] + delta;
    }
  }
}

class TestFlattenRuntime {
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

  public static function run():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);
      var x = new Tensor<I32>(ctx, [4]);
      x.fromArray([1, 2, 3, 4]);
      var state = new FlatState(x, 2, 4);
      var flatKernel = QD.kernel(ctx, macro (state:FlatState) -> {
        for (i in 0...state.n) {
          state.x[i] = state.x[i] + state.bias;
        }
      });
      flatKernel.launch(state);
      expectEq("flatten_launch_0", x.read(0), 3);
      expectEq("flatten_launch_3", x.read(3), 6);

      var nested = new NestedFlatState(state);
      var nestedKernel = QD.kernel(ctx, macro (state:NestedFlatState) -> {
        for (i in 0...state.inner.n) {
          state.inner.x[i] = state.inner.x[i] + state.inner.bias;
        }
      });
      nestedKernel.launch(nested);
      expectEq("flatten_nested_0", x.read(0), 5);
      expectEq("flatten_nested_3", x.read(3), 8);

      var keyA = Flattened.specKey(state).digest();
      var keyB = Flattened.specKey(new FlatState(x, 2, 8)).digest();
      expectTrue("flatten_spec_key_template_changes", keyA != keyB);

      var simTensor = new Tensor<I32>(ctx, [4]);
      simTensor.fromArray([0, 1, 2, 3]);
      var sim = new ParticleSim(ctx, simTensor, 4);
      sim.add(3);
      expectEq("data_oriented_0", simTensor.read(0), 3);
      expectEq("data_oriented_3", simTensor.read(3), 6);

      ctx.close();
    } catch (e:Dynamic) {
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
