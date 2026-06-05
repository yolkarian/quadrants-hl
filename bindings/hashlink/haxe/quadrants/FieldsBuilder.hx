package quadrants;

typedef FieldPlacementStep = {
  var kind:Int;
  var axis:Int;
  var size:Int;
  var chunkSize:Int;
}

class FieldsBuilder {
  static inline var SNODE_DENSE = 1;
  static inline var SNODE_DYNAMIC = 2;
  static inline var SNODE_POINTER = 3;
  static inline var SNODE_BITMASKED = 4;
  static inline var DEFAULT_DYNAMIC_CHUNK_SIZE = 128;

  final context:Context;
  var steps:Array<FieldPlacementStep> = [];
  var shape:Array<Int> = [];
  var finalized:Bool = false;

  function ensureMutable():Void {
    if (finalized) {
      throw "Quadrants field builder is finalized";
    }
  }

  function ensureHasSteps():Void {
    if (steps.length == 0) {
      throw "Quadrants field builder has no placement steps";
    }
  }

  public function new(context:Context) {
    this.context = context;
  }

  function add(kind:Int, axis:Axis, size:Int, chunkSize:Int):FieldsBuilder {
    ensureMutable();
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

  static function copySteps(steps:Array<FieldPlacementStep>):Array<FieldPlacementStep> {
    return [for (step in steps) {kind: step.kind, axis: step.axis, size: step.size, chunkSize: step.chunkSize}];
  }

  static function validateStepsMatchShape(shape:Array<Int>, steps:Array<FieldPlacementStep>):Void {
    if (steps.length != shape.length) {
      throw "Quadrants field placement step rank must match field shape rank";
    }
    for (axis in 0...shape.length) {
      var step = steps[axis];
      if (step.size != shape[axis]) {
        throw "Quadrants field placement step size must match field shape";
      }
      if (step.chunkSize <= 0) {
        throw "Quadrants dynamic field chunk size must be positive";
      }
    }
  }

  public static function placeDense(context:Context, field:FieldRuntime, shape:Array<Int>):Void {
    var checkedShape = TensorStorage.validateShape(shape);
    var denseSteps = [
      for (axis in 0...checkedShape.length)
        {kind: SNODE_DENSE, axis: axis, size: checkedShape[axis], chunkSize: DEFAULT_DYNAMIC_CHUNK_SIZE}
    ];
    placeWithSteps(context, field, checkedShape, denseSteps);
  }

  public static function placeWithSteps(context:Context, field:FieldRuntime, shape:Array<Int>, steps:Array<FieldPlacementStep>):Void {
    if (steps.length == 0) {
      throw "Quadrants field placement requires at least one SNode dimension";
    }
    field.ensurePlaceable();
    var tree = Native.snode_tree_create(context.nativeHandle());
    var parent = Native.snode_tree_root_id(tree);
    var checkedShape = TensorStorage.validateShape(shape);
    var checkedSteps = copySteps(steps);
    validateStepsMatchShape(checkedShape, checkedSteps);
    try {
      for (step in checkedSteps) {
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
      field.placeSNode(quadrants.TensorStorage.copyIntArray(checkedShape), snodeId, treeId, checkedSteps);
    } catch (e:Dynamic) {
      Native.snode_tree_close(tree);
      throw e;
    }
    Native.snode_tree_close(tree);
  }

  public function path():quadrants.snode.FieldPlacementPath {
    ensureHasSteps();
    return new quadrants.snode.FieldPlacementPath(context, quadrants.TensorStorage.copyIntArray(shape), copySteps(steps));
  }

  public function finalize():quadrants.snode.FieldPlacementPath {
    ensureMutable();
    var result = path();
    finalized = true;
    return result;
  }

  public function place(field:FieldRuntime):Void {
    ensureMutable();
    path().place(field);
  }

  public function placeMany(fields:Array<FieldRuntime>):quadrants.snode.FieldPlacementPath {
    ensureMutable();
    var result = path();
    result.placeMany(fields);
    return result;
  }

  public function destroy():Void {
    steps = [];
    shape = [];
    finalized = false;
  }
}
