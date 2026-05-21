// EXPECT_ERROR: Quadrants HashLink range-for only supports start...end, Ndrange.of(...), Ndrange.ranges(...), Grouped.of(...), Static.range(...), or Mesh.forVertices/forEdges/forFaces/forCells(...)
import quadrants.Context;
import quadrants.Kernel;

class UnsupportedForIterable {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (n, out) -> {
      for (i in n) {
        out[i] = i;
      }
    });
  }
}
