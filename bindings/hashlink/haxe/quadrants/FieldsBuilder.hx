package quadrants;

import quadrants.Native.QSNodeTree;

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
  static inline var SNODE_QUANT_ARRAY = 6;
  static inline var SNODE_BIT_STRUCT = 7;
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

  public function bitStruct(maxBits:Int):FieldsBuilder {
    ensureMutable();
    if (maxBits <= 0 || maxBits > 64) {
      throw "Quadrants bitStruct maxBits must be in 1...64";
    }
    steps.push({kind: SNODE_BIT_STRUCT, axis: -1, size: 1, chunkSize: maxBits});
    return this;
  }

  public function quantArray(axis:Axis, size:Int, maxNumBits:quadrants.quant.QuantBits):FieldsBuilder {
    return add(SNODE_QUANT_ARRAY, axis, size, maxNumBits);
  }

  static function copySteps(steps:Array<FieldPlacementStep>):Array<FieldPlacementStep> {
    return [for (step in steps) {kind: step.kind, axis: step.axis, size: step.size, chunkSize: step.chunkSize}];
  }

  static function validateStepsMatchShape(shape:Array<Int>, steps:Array<FieldPlacementStep>):Void {
    var shapeAxis = 0;
    for (step in steps) {
      if (step.kind == SNODE_BIT_STRUCT) {
        continue;
      }
      if (shapeAxis >= shape.length) {
        throw "Quadrants field placement step rank must match field shape rank";
      }
      if (step.size != shape[shapeAxis]) {
        throw "Quadrants field placement step size must match field shape";
      }
      if (step.chunkSize <= 0) {
        throw "Quadrants dynamic field chunk size must be positive";
      }
      shapeAxis++;
    }
    if (shapeAxis != shape.length) {
      throw "Quadrants field placement step rank must match field shape rank";
    }
  }

  static function hasQuantArrayStep(steps:Array<FieldPlacementStep>):Bool {
    for (step in steps) {
      if (step.kind == SNODE_QUANT_ARRAY) {
        return true;
      }
    }
    return false;
  }

  static function hasBitStructStep(steps:Array<FieldPlacementStep>):Bool {
    for (step in steps) {
      if (step.kind == SNODE_BIT_STRUCT) {
        return true;
      }
    }
    return false;
  }

  static function placeStructuralSteps(tree:QSNodeTree, parent:Int, steps:Array<FieldPlacementStep>):Int {
    var current = parent;
    for (step in steps) {
      current = Native.snode_tree_child(
        tree,
        current,
        step.kind,
        TensorStorage.nativeIntArray([step.axis]),
        TensorStorage.nativeIntArray([step.size]),
        step.chunkSize
      );
    }
    return current;
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
    field.ensurePlaceable();
    var checkedShape = TensorStorage.validateShape(shape);
    var checkedSteps = copySteps(steps);
    validateStepsMatchShape(checkedShape, checkedSteps);
    if (hasQuantArrayStep(checkedSteps)) {
      throw "Quadrants quantArray placement requires placeQuant(field, quantSpec)";
    }
    for (step in checkedSteps) {
      if (step.kind == SNODE_BIT_STRUCT) {
        throw "Quadrants bitStruct placement requires placeQuant(field, quantSpec)";
      }
    }
    var tree = Native.snode_tree_create(context.nativeHandle());
    var parent = Native.snode_tree_root_id(tree);
    try {
      parent = placeStructuralSteps(tree, parent, checkedSteps);
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

  public static function placeQuantWithSteps<T>(context:Context,
      field:Field<T>,
      shape:Array<Int>,
      steps:Array<FieldPlacementStep>,
      spec:quadrants.quant.QuantStorageSpec<T>):Void {
    if (spec == null) {
      throw "Quadrants quant field placement requires a quant storage spec";
    }
    if (field == null) {
      throw "Quadrants quant field placement requires a Field";
    }
    var runtime:FieldRuntime = cast field;
    runtime.ensurePlaceable();
    if (runtime.dtype != spec.computeDType) {
      throw "Quadrants quant field compute dtype must match the Field dtype";
    }
    var checkedShape = TensorStorage.validateShape(shape);
    var checkedSteps = copySteps(steps);
    validateStepsMatchShape(checkedShape, checkedSteps);
    if (!hasQuantArrayStep(checkedSteps) && !hasBitStructStep(checkedSteps)) {
      throw "Quadrants placeQuant requires a quantArray or bitStruct placement step";
    }
    for (step in checkedSteps) {
      if ((step.kind == SNODE_QUANT_ARRAY || step.kind == SNODE_BIT_STRUCT) && spec.bits > step.chunkSize) {
        throw "Quadrants quant spec bit width exceeds quant placement maxNumBits";
      }
    }
    if (spec.offset != 0.0) {
      throw "Quadrants quant fixed offset placement is not supported by the HashLink bridge";
    }
    var tree = Native.snode_tree_create(context.nativeHandle());
    var parent = Native.snode_tree_root_id(tree);
    try {
      for (step in checkedSteps) {
        if (step.kind == SNODE_BIT_STRUCT) {
          parent = Native.snode_tree_bit_struct_quant_child(
            tree,
            parent,
            runtime.dtype,
            spec.kind,
            spec.bits,
            spec.signed ? 1 : 0,
            spec.fractionalBits,
            spec.exponentBits,
            spec.fractionBits,
            spec.scale,
            step.chunkSize
          );
        } else {
          parent = Native.snode_tree_child(
            tree,
            parent,
            step.kind,
            TensorStorage.nativeIntArray([step.axis]),
            TensorStorage.nativeIntArray([step.size]),
            step.chunkSize
          );
        }
      }
      var name = @:privateAccess "".toUtf8();
      var snodeId = Native.snode_tree_place_quant(
        tree,
        parent,
        runtime.dtype,
        spec.kind,
        spec.bits,
        spec.signed ? 1 : 0,
        spec.fractionalBits,
        spec.exponentBits,
        spec.fractionBits,
        spec.scale,
        name
      );
      var treeId = Native.snode_tree_commit(context.nativeHandle(), tree);
      runtime.placeSNode(quadrants.TensorStorage.copyIntArray(checkedShape), snodeId, treeId, checkedSteps);
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

  public function placeQuant<T>(field:Field<T>, spec:quadrants.quant.QuantStorageSpec<T>):Void {
    ensureMutable();
    path().placeQuant(field, spec);
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
