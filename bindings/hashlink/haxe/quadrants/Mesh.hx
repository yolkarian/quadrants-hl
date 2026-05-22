package quadrants;

enum abstract MeshElementType(Int) from Int to Int {
  var Vertex = 0;
  var Edge = 1;
  var Face = 2;
  var Cell = 3;
}

class Mesh {
  final counts:Array<Int>;
  final relations:Array<Array<Array<Int>>>;


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
  }

  public function count(type:MeshElementType):Int {
    return counts[type];
  }

  inline function relationId(from:MeshElementType, to:MeshElementType):Int {
    return from * 4 + to;
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

  public function vertices():Iterator<Int> return 0...counts[MeshElementType.Vertex];
  public function edges():Iterator<Int> return 0...counts[MeshElementType.Edge];
  public function faces():Iterator<Int> return 0...counts[MeshElementType.Face];
  public function cells():Iterator<Int> return 0...counts[MeshElementType.Cell];
}
