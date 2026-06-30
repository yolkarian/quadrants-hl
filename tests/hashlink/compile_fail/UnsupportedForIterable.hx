// EXPECT_ERROR: Quadrants HashLink range-for only supports start...end, Ndrange.of*/ranges* helpers, Grouped.of(...), Static.range(...), or Mesh.forVertices/forEdges/forFaces/forCells(...)
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class UnsupportedForIterable {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (n:Int, out:Tensor<I32>) -> {
      for (i in n) {
        out[i] = i;
      }
    });
  }
}
