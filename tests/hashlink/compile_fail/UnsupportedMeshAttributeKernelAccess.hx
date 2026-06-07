// EXPECT_ERROR: kernel mesh relation/attribute access requires descriptor mesh resource metadata
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.mesh.MeshAttribute;
import quadrants.mesh.Vertex;

class UnsupportedMeshAttributeKernelAccess {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    Kernel.build(ctx, macro (attribute:MeshAttribute<Vertex, I32>, out:Tensor<I32>) -> {
      out[0] = 0;
    });
  }
}
