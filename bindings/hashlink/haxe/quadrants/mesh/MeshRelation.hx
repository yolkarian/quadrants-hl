package quadrants.mesh;

class MeshRelation<From, To> {
  public final mesh:quadrants.Mesh;
  public final from:MeshElementKind<From>;
  public final to:MeshElementKind<To>;

  public function new(mesh:quadrants.Mesh, from:MeshElementKind<From>, to:MeshElementKind<To>) {
    if (mesh == null) {
      throw "Quadrants mesh relation requires a mesh";
    }
    this.mesh = mesh;
    this.from = from;
    this.to = to;
  }

  public function set(source:MeshElement<From>, targets:Array<MeshElement<To>>):Void {
    requireSource(source);
    if (targets == null) {
      throw "Quadrants mesh relation target list is null";
    }
    mesh.setRelation(from.type, source.index, to.type, [for (target in targets) requireTarget(target).index]);
  }

  public function size(source:MeshElement<From>):Int {
    requireSource(source);
    return mesh.relationSize(from.type, source.index, to.type);
  }

  public function get(source:MeshElement<From>, neighborIndex:Int):MeshElement<To> {
    requireSource(source);
    return new MeshElement(mesh, to, mesh.relationAccess(from.type, source.index, to.type, neighborIndex));
  }

  function requireSource(source:MeshElement<From>):MeshElement<From> {
    if (source == null || source.mesh != mesh || source.kind != from) {
      throw "Quadrants mesh relation source element mismatch";
    }
    return source;
  }

  function requireTarget(target:MeshElement<To>):MeshElement<To> {
    if (target == null || target.mesh != mesh || target.kind != to) {
      throw "Quadrants mesh relation target element mismatch";
    }
    return target;
  }
}
