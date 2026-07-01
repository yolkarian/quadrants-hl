package quadrants;

import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.Types.I32;
import quadrants.mesh.MeshAttribute;
import quadrants.mesh.MeshDomain;
import quadrants.mesh.MeshElement;
import quadrants.mesh.MeshElementKind;
import quadrants.mesh.MeshKinds;
import quadrants.mesh.MeshRelation;

enum abstract MeshElementType(Int) from Int to Int {
  var Vertex = 0;
  var Edge = 1;
  var Face = 2;
  var Cell = 3;
}

enum abstract MeshIndexConversion(Int) from Int to Int {
  var LocalToGlobal = 0;
  var LocalToReordered = 1;
  var GlobalToReordered = 2;
}

private typedef MeshNativeOffsets = {
  var context:Context;
  var owned:Array<Field<I32>>;
  var total:Array<Field<I32>>;
}

private typedef MeshNativeIndexMappings = {
  var context:Context;
  var fields:Array<Field<I32>>;
}

class Mesh {
  final counts:Array<Int>;
  final relations:Array<Array<Array<Int>>>;
  final indexMappings:Array<Null<Array<Int>>>;
  var nativeOffsets:Array<MeshNativeOffsets> = [];
  var nativeIndexMappings:Array<MeshNativeIndexMappings> = [];
  var indexMappingVersion:Int = 0;


  public static function load(context:Context, path:String):Mesh {
    if (context == null) {
      throw "Quadrants Mesh.load requires a Context";
    }
    if (path == null || path.length == 0) {
      throw "Quadrants Mesh.load requires a path";
    }
    var raw:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
    if (Reflect.field(raw, "format") != "quadrants-hl.mesh.v1") {
      throw "Quadrants Mesh.load requires a quadrants-hl.mesh.v1 JSON file";
    }
    var rawCounts:Array<Dynamic> = cast Reflect.field(raw, "counts");
    if (rawCounts == null || rawCounts.length != 4) {
      throw "Quadrants Mesh.load counts must contain four element counts";
    }
    var mesh = new Mesh(
      parseNonNegativeInt(rawCounts[0], "vertices"),
      parseNonNegativeInt(rawCounts[1], "edges"),
      parseNonNegativeInt(rawCounts[2], "faces"),
      parseNonNegativeInt(rawCounts[3], "cells")
    );
    var rawMappings:Array<Dynamic> = cast Reflect.field(raw, "indexMappings");
    if (rawMappings != null) {
      for (entry in rawMappings) {
        var type:MeshElementType = cast parseElementType(Reflect.field(entry, "type"), "indexMapping.type");
        var conversion:MeshIndexConversion = cast parseConversion(Reflect.field(entry, "conversion"));
        var rawValues:Array<Dynamic> = cast Reflect.field(entry, "values");
        if (rawValues == null) {
          throw "Quadrants Mesh.load index mapping values must be an array";
        }
        mesh.setIndexMapping(type, conversion, [for (value in rawValues) parseNonNegativeInt(value, "index mapping value")]);
      }
    }
    var rawRelations:Array<Dynamic> = cast Reflect.field(raw, "relations");
    if (rawRelations == null) {
      return mesh;
    }
    for (entry in rawRelations) {
      var from:MeshElementType = cast parseElementType(Reflect.field(entry, "from"), "relation.from");
      var to:MeshElementType = cast parseElementType(Reflect.field(entry, "to"), "relation.to");
      var rows:Array<Dynamic> = cast Reflect.field(entry, "targets");
      if (rows == null || rows.length != mesh.count(from)) {
        throw "Quadrants Mesh.load relation row count mismatch";
      }
      for (row in 0...rows.length) {
        var rawTargets:Array<Dynamic> = cast rows[row];
        if (rawTargets == null) {
          throw "Quadrants Mesh.load relation row must be an array";
        }
        var targets = new Array<Int>();
        for (target in rawTargets) {
          targets.push(parseNonNegativeInt(target, "relation target"));
        }
        mesh.setRelation(from, row, to, targets);
      }
    }
    return mesh;
  }

  public static inline function forVertices(count:Int):Iterator<Int> return 0...count;
  public static inline function forEdges(count:Int):Iterator<Int> return 0...count;
  public static inline function forFaces(count:Int):Iterator<Int> return 0...count;
  public static inline function forCells(count:Int):Iterator<Int> return 0...count;
  public function new(vertices:Int, edges:Int = 0, faces:Int = 0, cells:Int = 0) {
    if (vertices < 0 || edges < 0 || faces < 0 || cells < 0) {
      throw "Quadrants mesh element counts must be non-negative";
    }
    counts = [vertices, edges, faces, cells];
    relations = [for (_ in 0...16) null];
    indexMappings = [for (_ in 0...12) null];
  }

  public function count(type:MeshElementType):Int {
    return counts[type];
  }

  @:noCompletion public function __qdNativeCounts():hl.NativeArray<Int> {
    return TensorStorage.nativeIntArray([for (value in counts) value]);
  }

  function ensureNativeOffsets(ctx:Context):MeshNativeOffsets {
    for (entry in nativeOffsets) {
      if (entry.context == ctx) {
        return entry;
      }
    }
    var owned = new Array<Field<I32>>();
    var total = new Array<Field<I32>>();
    for (type in 0...4) {
      var ownedField = new Field<I32>(ctx, [2]);
      ownedField.write(0, 0);
      ownedField.write(1, counts[type]);
      var totalField = new Field<I32>(ctx, [2]);
      totalField.write(0, 0);
      totalField.write(1, counts[type]);
      owned.push(ownedField);
      total.push(totalField);
    }
    var entry = {context: ctx, owned: owned, total: total};
    nativeOffsets.push(entry);
    return entry;
  }

  @:noCompletion public function __qdOwnedOffsetSNodeIds(ctx:Context):hl.NativeArray<Int> {
    var entry = ensureNativeOffsets(ctx);
    return TensorStorage.nativeIntArray([for (field in entry.owned) (cast field : FieldRuntime).snodeId]);
  }

  @:noCompletion public function __qdTotalOffsetSNodeIds(ctx:Context):hl.NativeArray<Int> {
    var entry = ensureNativeOffsets(ctx);
    return TensorStorage.nativeIntArray([for (field in entry.total) (cast field : FieldRuntime).snodeId]);
  }

  inline function relationId(from:MeshElementType, to:MeshElementType):Int {
    return from * 4 + to;
  }

  inline function mappingId(type:MeshElementType, conversion:MeshIndexConversion):Int {
    return type * 3 + conversion;
  }

  function checkElement(type:MeshElementType, index:Int):Void {
    if (index < 0 || index >= count(type)) {
      throw "Quadrants mesh element index out of bounds";
    }
  }

  function ensureRelation(from:MeshElementType, to:MeshElementType):Array<Array<Int>> {
    var id = relationId(from, to);
    var relation = relations[id];
    if (relation == null) {
      relation = [for (_ in 0...count(from)) []];
      relations[id] = relation;
    }
    return relation;
  }

  public function setRelation(from:MeshElementType, fromIndex:Int, to:MeshElementType, targets:Array<Int>):Void {
    checkElement(from, fromIndex);
    for (target in targets) {
      checkElement(to, target);
    }
    ensureRelation(from, to)[fromIndex] = [for (target in targets) target];
  }

  public function neighbors(from:MeshElementType, fromIndex:Int, to:MeshElementType):Array<Int> {
    checkElement(from, fromIndex);
    var relation = relations[relationId(from, to)];
    return relation == null ? [] : [for (target in relation[fromIndex]) target];
  }

  public function save(path:String):Void {
    if (path == null || path.length == 0) {
      throw "Quadrants Mesh.save requires a path";
    }
    var serializedRelations = new Array<{from:Int, to:Int, targets:Array<Array<Int>>}>();
    for (from in 0...4) {
      for (to in 0...4) {
        var relation = relations[relationId(cast from, cast to)];
        if (relation != null) {
          serializedRelations.push({
            from: from,
            to: to,
            targets: [for (row in relation) [for (target in row) target]]
          });
        }
      }
    }
    var serializedMappings = new Array<{type:Int, conversion:Int, values:Array<Int>}>();
    for (type in 0...4) {
      for (conversion in 0...3) {
        var mapping = indexMappings[mappingId(cast type, cast conversion)];
        if (mapping != null) {
          serializedMappings.push({type: type, conversion: conversion, values: [for (value in mapping) value]});
        }
      }
    }
    sys.io.File.saveContent(path, haxe.Json.stringify({
      format: "quadrants-hl.mesh.v1",
      counts: [for (value in counts) value],
      relations: serializedRelations,
      indexMappings: serializedMappings
    }));
  }

  public function reorder(type:MeshElementType, newToOld:Array<Int>):Mesh {
    var oldToNew = validateReorder(type, newToOld);
    var result = new Mesh(counts[0], counts[1], counts[2], counts[3]);
    for (from in 0...4) {
      for (to in 0...4) {
        var relation = relations[relationId(cast from, cast to)];
        if (relation == null) {
          continue;
        }
        var rows = new Array<Array<Int>>();
        for (newSource in 0...counts[from]) {
          var oldSource = from == type ? newToOld[newSource] : newSource;
          rows.push([for (target in relation[oldSource]) to == type ? oldToNew[target] : target]);
        }
        result.relations[relationId(cast from, cast to)] = rows;
      }
    }
    for (i in 0...indexMappings.length) {
      var mapping = indexMappings[i];
      if (mapping != null) result.indexMappings[i] = [for (value in mapping) value];
    }
    result.setIndexMapping(type, MeshIndexConversion.LocalToReordered, oldToNew);
    return result;
  }

  public function relationSize(from:MeshElementType, fromIndex:Int, to:MeshElementType):Int {
    checkElement(from, fromIndex);
    var relation = relations[relationId(from, to)];
    return relation == null ? 0 : relation[fromIndex].length;
  }

  public function relationAccess(from:MeshElementType, fromIndex:Int, to:MeshElementType, neighborIndex:Int):Int {
    var values = neighbors(from, fromIndex, to);
    if (neighborIndex < 0 || neighborIndex >= values.length) {
      throw "Quadrants mesh neighbor index out of bounds";
    }
    return values[neighborIndex];
  }

  public function setIndexMapping(type:MeshElementType, conversion:MeshIndexConversion, values:Array<Int>):Void {
    if (values == null || values.length != count(type)) {
      throw "Quadrants mesh index mapping length must match the mesh domain";
    }
    for (value in values) {
      if (value < 0) {
        throw "Quadrants mesh index mapping values must be non-negative";
      }
    }
    indexMappings[mappingId(type, conversion)] = [for (value in values) value];
    indexMappingVersion++;
    for (entry in nativeIndexMappings) {
      for (field in entry.fields) {
        if (field != null) field.close();
      }
    }
    nativeIndexMappings = [];
  }

  public function convertIndex(type:MeshElementType, conversion:MeshIndexConversion, index:Int):Int {
    checkElement(type, index);
    var mapping = indexMappings[mappingId(type, conversion)];
    return mapping == null ? index : mapping[index];
  }

  @:noCompletion public function __qdIndexMappingVersion():Int {
    return indexMappingVersion;
  }

  @:noCompletion public function __qdIndexMappingSNodeIds(ctx:Context):hl.NativeArray<Int> {
    for (entry in nativeIndexMappings) {
      if (entry.context == ctx) {
        return TensorStorage.nativeIntArray([for (field in entry.fields) field == null ? -1 : (cast field : FieldRuntime).snodeId]);
      }
    }
    var fields = new Array<Field<I32>>();
    for (i in 0...indexMappings.length) {
      var mapping = indexMappings[i];
      if (mapping == null) {
        fields.push(null);
      } else {
        var field = new Field<I32>(ctx, [mapping.length]);
        for (j in 0...mapping.length) field.write(j, mapping[j]);
        fields.push(field);
      }
    }
    nativeIndexMappings.push({context: ctx, fields: fields});
    return TensorStorage.nativeIntArray([for (field in fields) field == null ? -1 : (cast field : FieldRuntime).snodeId]);
  }


  public function domain<T>(kind:MeshElementKind<T>):MeshDomain<T> {
    return new MeshDomain(this, kind);
  }

  public function element<T>(kind:MeshElementKind<T>, index:Int):MeshElement<T> {
    return new MeshElement(this, kind, index);
  }

  public function relation<From, To>(from:MeshElementKind<From>, to:MeshElementKind<To>):MeshRelation<From, To> {
    return new MeshRelation(this, from, to);
  }

  public function attribute<Element, Value>(kind:MeshElementKind<Element>, storage:Field<Value>):MeshAttribute<Element, Value> {
    return new MeshAttribute(this, kind, storage);
  }

  public function typedVertices():MeshDomain<quadrants.mesh.Vertex> return domain(MeshKinds.vertex);
  public function typedEdges():MeshDomain<quadrants.mesh.Edge> return domain(MeshKinds.edge);
  public function typedFaces():MeshDomain<quadrants.mesh.Face> return domain(MeshKinds.face);
  public function typedCells():MeshDomain<quadrants.mesh.Cell> return domain(MeshKinds.cell);
  public function vertices():Iterator<Int> return 0...counts[MeshElementType.Vertex];
  public function edges():Iterator<Int> return 0...counts[MeshElementType.Edge];
  public function faces():Iterator<Int> return 0...counts[MeshElementType.Face];
  public function cells():Iterator<Int> return 0...counts[MeshElementType.Cell];

  function validateReorder(type:MeshElementType, newToOld:Array<Int>):Array<Int> {
    if (newToOld == null || newToOld.length != count(type)) {
      throw "Quadrants Mesh.reorder mapping length must match the mesh domain";
    }
    var oldToNew = [for (_ in 0...count(type)) -1];
    for (newIndex in 0...newToOld.length) {
      var oldIndex = newToOld[newIndex];
      checkElement(type, oldIndex);
      if (oldToNew[oldIndex] >= 0) {
        throw "Quadrants Mesh.reorder mapping contains a duplicate source index";
      }
      oldToNew[oldIndex] = newIndex;
    }
    return oldToNew;
  }

  static function parseNonNegativeInt(value:Dynamic, name:String):Int {
    var parsed:Float = value;
    var asInt = Std.int(parsed);
    if (Math.isNaN(parsed) || parsed < 0 || parsed != asInt) {
      throw 'Quadrants Mesh.load ${name} must be a non-negative integer';
    }
    return asInt;
  }

  static function parseElementType(value:Dynamic, name:String):Int {
    var parsed = parseNonNegativeInt(value, name);
    if (parsed >= 4) {
      throw 'Quadrants Mesh.load ${name} is not a valid element type';
    }
    return parsed;
  }

  static function parseConversion(value:Dynamic):Int {
    var parsed = parseNonNegativeInt(value, "indexMapping.conversion");
    if (parsed >= 3) {
      throw "Quadrants Mesh.load indexMapping.conversion is not a valid conversion type";
    }
    return parsed;
  }
}
