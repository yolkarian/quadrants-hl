// EXPECT_ERROR: kernel mesh relation/attribute access requires descriptor mesh resource metadata
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.mesh.Face;
import quadrants.mesh.MeshRelation;
import quadrants.mesh.Vertex;

class UnsupportedMeshRelationKernelAccess {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    Kernel.build(ctx, macro (relation:MeshRelation<Vertex, Face>, out:Tensor<I32>) -> {
      out[0] = 0;
    });
  }
}
