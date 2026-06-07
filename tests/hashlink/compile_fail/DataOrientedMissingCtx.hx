// EXPECT_ERROR: Quadrants @:qdDataOriented class requires a ctx field named ctx
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.flatten.DataOriented;

@:qdDataOriented("ctx")
class BrokenSim extends DataOriented {
  public final x:Tensor<I32>;

  public function new(x:Tensor<I32>) {
    this.x = x;
  }

  @:kernel
  public function step(delta:I32):Void {
    x[0] = x[0] + delta;
  }
}

class DataOrientedMissingCtx {
  static function main():Void {}
}
