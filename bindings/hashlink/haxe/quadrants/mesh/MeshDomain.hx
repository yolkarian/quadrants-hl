package quadrants.mesh;

class MeshDomain<T> {
  public final mesh:quadrants.Mesh;
  public final kind:MeshElementKind<T>;

  public function new(mesh:quadrants.Mesh, kind:MeshElementKind<T>) {
    this.mesh = mesh;
    this.kind = kind;
  }

  public function count():Int {
    return mesh.count(kind.type);
  }

  public function get(index:Int):MeshElement<T> {
    return new MeshElement(mesh, kind, index);
  }

  public function iterator():Iterator<MeshElement<T>> {
    var domain = this;
    var nextIndex = 0;
    return {
      hasNext: function():Bool return nextIndex < domain.count(),
      next: function():MeshElement<T> return domain.get(nextIndex++)
    };
  }
}
