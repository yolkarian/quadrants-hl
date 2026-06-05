package quadrants.mesh;

class MeshElement<T> {
  public final mesh:quadrants.Mesh;
  public final kind:MeshElementKind<T>;
  public final index:Int;

  public function new(mesh:quadrants.Mesh, kind:MeshElementKind<T>, index:Int) {
    if (mesh == null) {
      throw "Quadrants mesh element requires a mesh";
    }
    if (index < 0 || index >= mesh.count(kind.type)) {
      throw "Quadrants mesh element index out of bounds";
    }
    this.mesh = mesh;
    this.kind = kind;
    this.index = index;
  }
}
