// EXPECT_ERROR: Quadrants QdArgs field state.label cannot use String
import quadrants.Context;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

@:qdFlatten
class FlattenPrimitiveState {
  public final x:Tensor<I32>;
  public final label:String;

  public function new(x:Tensor<I32>, label:String) {
    this.x = x;
    this.label = label;
  }
}

class FlattenPrimitiveMissingMetadata {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    QD.kernel(ctx, macro (state:FlattenPrimitiveState) -> {
      state.x[0] = 1;
    });
  }
}
