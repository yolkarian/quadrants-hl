// EXPECT_ERROR: Quadrants flatten primitive field state.n must be marked @:template or @:param
import quadrants.Context;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

@:qdFlatten
class FlattenPrimitiveState {
  public final x:Tensor<I32>;
  public final n:I32;

  public function new(x:Tensor<I32>, n:I32) {
    this.x = x;
    this.n = n;
  }
}

class FlattenPrimitiveMissingMetadata {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    QD.kernel(ctx, macro (state:FlattenPrimitiveState) -> {
      state.x[0] = state.n;
    });
  }
}
