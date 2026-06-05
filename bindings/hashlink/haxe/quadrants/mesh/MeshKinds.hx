package quadrants.mesh;

import quadrants.Mesh.MeshElementType;

class MeshKinds {
  public static final vertex:MeshElementKind<Vertex> = new MeshElementKind(MeshElementType.Vertex, "vertex");
  public static final edge:MeshElementKind<Edge> = new MeshElementKind(MeshElementType.Edge, "edge");
  public static final face:MeshElementKind<Face> = new MeshElementKind(MeshElementType.Face, "face");
  public static final cell:MeshElementKind<Cell> = new MeshElementKind(MeshElementType.Cell, "cell");
}
