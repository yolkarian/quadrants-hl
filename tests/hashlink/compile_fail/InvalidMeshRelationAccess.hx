// EXPECT_ERROR: quadrants.mesh.Edge should be quadrants.mesh.Vertex
import quadrants.Mesh;
import quadrants.mesh.MeshKinds;

class InvalidMeshRelationAccess {
  static function main():Void {
    var mesh = new Mesh(1, 1, 1);
    var relation = mesh.relation(MeshKinds.vertex, MeshKinds.face);
    var edge = mesh.element(MeshKinds.edge, 0);
    relation.size(edge);
  }
}
