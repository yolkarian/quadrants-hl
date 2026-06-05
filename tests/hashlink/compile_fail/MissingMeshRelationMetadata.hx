// EXPECT_ERROR: has no field relationSize
import quadrants.Mesh;
import quadrants.mesh.MeshKinds;

class MissingMeshRelationMetadata {
  static function main():Void {
    var mesh = new Mesh(1, 0, 0);
    var vertex = mesh.element(MeshKinds.vertex, 0);
    vertex.relationSize(MeshKinds.face);
  }
}
