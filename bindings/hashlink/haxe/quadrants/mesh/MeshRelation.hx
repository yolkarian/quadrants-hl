package quadrants.mesh;

import quadrants.Context;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.Native;
import quadrants.Native.QMeshRelation;
import quadrants.Types.I32;

typedef MeshRelationNativeEntry = {
  var context:Context;
  var valueField:Field<I32>;
  var offsetField:Field<I32>;
  var patchOffsetField:Field<I32>;
  var valueCount:Int;
  var fixed:Bool;
  var fixedDegree:Int;
  var handle:QMeshRelation;
}

class MeshRelation<From, To> {
  public final mesh:quadrants.Mesh;
  public final from:MeshElementKind<From>;
  public final to:MeshElementKind<To>;
  var nativeEntries:Array<MeshRelationNativeEntry> = [];
  var dirty:Bool = true;

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
    dirty = true;
  }

  public function size(source:MeshElement<From>):Int {
    requireSource(source);
    return mesh.relationSize(from.type, source.index, to.type);
  }

  public function get(source:MeshElement<From>, neighborIndex:Int):MeshElement<To> {
    requireSource(source);
    return new MeshElement(mesh, to, mesh.relationAccess(from.type, source.index, to.type, neighborIndex));
  }

  @:noCompletion public function __qdNativeRelation(ctx:Context):QMeshRelation {
    return ensureNativeRelation(ctx).handle;
  }

  function elementOrder(type:Int):Int {
    return type;
  }

  function fixedDegree():Int {
    var fromOrder = elementOrder(from.type);
    var toOrder = elementOrder(to.type);
    if (fromOrder <= toOrder) {
      return 0;
    }
    return from.type == 3 && to.type == 1 ? 6 : fromOrder + 1;
  }

  function closeNativeEntry(entry:MeshRelationNativeEntry):Void {
    if (entry.handle != null) Native.mesh_relation_close(entry.handle);
    if (entry.valueField != null) entry.valueField.close();
    if (entry.offsetField != null) entry.offsetField.close();
    if (entry.patchOffsetField != null) entry.patchOffsetField.close();
  }

  function ensureNativeRelation(ctx:Context):MeshRelationNativeEntry {
    if (ctx == null) {
      throw "Quadrants MeshRelation kernel launch requires a Context";
    }
    var sourceCount = mesh.count(from.type);
    var degree = fixedDegree();
    var fixed = degree > 0;
    var valueCount = 0;
    if (fixed) {
      valueCount = sourceCount * degree;
    } else {
      for (i in 0...sourceCount) valueCount += mesh.relationSize(from.type, i, to.type);
    }
    if (valueCount <= 0) valueCount = 1;
    for (entry in nativeEntries) {
      if (entry.context == ctx && !dirty && entry.valueCount == valueCount && entry.fixed == fixed && entry.fixedDegree == degree) {
        return entry;
      }
    }
    var retained = new Array<MeshRelationNativeEntry>();
    for (entry in nativeEntries) {
      if (entry.context == ctx) closeNativeEntry(entry); else retained.push(entry);
    }
    nativeEntries = retained;

    var valueField = new Field<I32>(ctx, [valueCount]);
    var offsetField = new Field<I32>(ctx, [sourceCount + 1]);
    var patchOffsetField = new Field<I32>(ctx, [1]);
    patchOffsetField.write(0, 0);
    var cursor = 0;
    for (i in 0...sourceCount) {
      offsetField.write(i, cursor);
      if (fixed) {
        var targets = mesh.neighbors(from.type, i, to.type);
        for (j in 0...degree) {
          valueField.write(i * degree + j, j < targets.length ? targets[j] : -1);
        }
        cursor += degree;
      } else {
        var targets = mesh.neighbors(from.type, i, to.type);
        for (target in targets) {
          valueField.write(cursor++, target);
        }
      }
    }
    offsetField.write(sourceCount, cursor);
    if (cursor == 0) valueField.write(0, -1);

    var valueRuntime:FieldRuntime = cast valueField;
    var offsetRuntime:FieldRuntime = cast offsetField;
    var patchRuntime:FieldRuntime = cast patchOffsetField;
    var handle = Native.mesh_relation_create(
      ctx.nativeHandle(),
      from.type,
      to.type,
      mesh.__qdNativeCounts(),
      mesh.__qdOwnedOffsetSNodeIds(ctx),
      mesh.__qdTotalOffsetSNodeIds(ctx),
      valueRuntime.snodeId,
      offsetRuntime.snodeId,
      patchRuntime.snodeId,
      fixed ? 1 : 0,
      degree
    );
    var created = {context: ctx, valueField: valueField, offsetField: offsetField, patchOffsetField: patchOffsetField, valueCount: valueCount, fixed: fixed, fixedDegree: degree, handle: handle};
    nativeEntries.push(created);
    dirty = false;
    return created;
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
