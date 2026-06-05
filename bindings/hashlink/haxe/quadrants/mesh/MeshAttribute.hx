package quadrants.mesh;

import quadrants.Field;
import quadrants.FieldRuntime;

class MeshAttribute<Element, Value> {
  public final mesh:quadrants.Mesh;
  public final kind:MeshElementKind<Element>;
  public final storage:Field<Value>;

  public function new(mesh:quadrants.Mesh, kind:MeshElementKind<Element>, storage:Field<Value>) {
    if (mesh == null) {
      throw "Quadrants mesh attribute requires a mesh";
    }
    var runtime:FieldRuntime = cast storage;
    if (runtime.shape == null || runtime.elementCount() != mesh.count(kind.type)) {
      throw "Quadrants mesh attribute storage element count must match its mesh domain";
    }
    this.mesh = mesh;
    this.kind = kind;
    this.storage = storage;
  }

  public inline function read(element:MeshElement<Element>):Value {
    requireElement(element);
    return storage.read(element.index);
  }

  public inline function write(element:MeshElement<Element>, value:Value):Void {
    requireElement(element);
    storage.write(element.index, value);
  }

  function requireElement(element:MeshElement<Element>):Void {
    if (element == null || element.mesh != mesh || element.kind != kind) {
      throw "Quadrants mesh attribute element mismatch";
    }
  }
}
