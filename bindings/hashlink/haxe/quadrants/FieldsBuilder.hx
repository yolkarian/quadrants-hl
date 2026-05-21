package quadrants;

class FieldsBuilder {
  static inline var SNODE_DENSE = 1;
  static inline var SNODE_DYNAMIC = 2;
  static inline var SNODE_POINTER = 3;
  static inline var SNODE_BITMASKED = 4;
  static inline var DEFAULT_DYNAMIC_CHUNK_SIZE = 128;

  final context:Context;
  var steps:Array<{kind:Int, axis:Int, size:Int, chunkSize:Int}> = [];
  var shape:Array<Int> = [];

  public function new(context:Context) {
    this.context = context;
  }

  function add(kind:Int, axis:Axis, size:Int, chunkSize:Int):FieldsBuilder {
    if (size <= 0) {
      throw "Quadrants field SNode size must be positive";
    }
    if (chunkSize <= 0) {
      throw "Quadrants dynamic field chunk size must be positive";
    }
    steps.push({kind: kind, axis: axis, size: size, chunkSize: chunkSize});
    shape.push(size);
    return this;
  }

  public function dense(axis:Axis, size:Int):FieldsBuilder {
    return add(SNODE_DENSE, axis, size, DEFAULT_DYNAMIC_CHUNK_SIZE);
  }

  public function pointer(axis:Axis, size:Int):FieldsBuilder {
    return add(SNODE_POINTER, axis, size, DEFAULT_DYNAMIC_CHUNK_SIZE);
  }

  public function bitmasked(axis:Axis, size:Int):FieldsBuilder {
    return add(SNODE_BITMASKED, axis, size, DEFAULT_DYNAMIC_CHUNK_SIZE);
  }

  public function dynamicNode(axis:Axis, size:Int, chunkSize:Int = DEFAULT_DYNAMIC_CHUNK_SIZE):FieldsBuilder {
    return add(SNODE_DYNAMIC, axis, size, chunkSize);
  }

  public function dynamic_(axis:Axis, size:Int, chunkSize:Int = DEFAULT_DYNAMIC_CHUNK_SIZE):FieldsBuilder {
    return dynamicNode(axis, size, chunkSize);
  }

  public static function placeDense(context:Context, field:FieldRuntime, shape:Array<Int>):Void {
    var checkedShape = TensorStorage.validateShape(shape);
    var denseSteps = [
      for (axis in 0...checkedShape.length)
        {kind: SNODE_DENSE, axis: axis, size: checkedShape[axis], chunkSize: DEFAULT_DYNAMIC_CHUNK_SIZE}
    ];
    placeSteps(context, field, checkedShape, denseSteps);
  }

  static function placeSteps(context:Context, field:FieldRuntime, shape:Array<Int>, steps:Array<{kind:Int, axis:Int, size:Int, chunkSize:Int}>):Void {
    if (steps.length == 0) {
      throw "Quadrants field placement requires at least one SNode dimension";
    }
    field.ensurePlaceable();
    var tree = Native.snode_tree_create(context.nativeHandle());
    var parent = Native.snode_tree_root_id(tree);
    try {
      for (step in steps) {
        parent = Native.snode_tree_child(
          tree,
          parent,
          step.kind,
          TensorStorage.nativeIntArray([step.axis]),
          TensorStorage.nativeIntArray([step.size]),
          step.chunkSize
        );
      }
      var name = @:privateAccess "".toUtf8();
      var snodeId = Native.snode_tree_place(tree, parent, field.dtype, name);
      var treeId = Native.snode_tree_commit(context.nativeHandle(), tree);
      field.placeSNode(shape.copy(), snodeId, treeId);
    } catch (e:Dynamic) {
      Native.snode_tree_close(tree);
      throw e;
    }
    Native.snode_tree_close(tree);
  }

  public function place(field:FieldRuntime):Void {
    placeSteps(context, field, shape.copy(), steps.copy());
  }

  public function destroy():Void {
    steps = [];
    shape = [];
  }
}
