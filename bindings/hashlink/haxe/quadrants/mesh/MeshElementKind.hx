package quadrants.mesh;

import quadrants.Mesh.MeshElementType;

class MeshElementKind<T> {
  public final type:MeshElementType;
  public final label:String;

  public function new(type:MeshElementType, label:String) {
    this.type = type;
    this.label = label;
  }
}
