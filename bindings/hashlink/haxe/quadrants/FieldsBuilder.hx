package quadrants;

import quadrants.Native.QSNodeTree;

typedef FieldPlacementStep = {
  var kind:Int;
  var axes:Array<Int>;
  var sizes:Array<Int>;
  var chunkSize:Int;
}

typedef FieldPlacementOptions = {
  ?order:Array<Int>,
  ?layout:Layout,
  ?offset:Array<Int>,
  ?chunkSize:Int,
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
  var placementOffset:Null<Array<Int>> = null;
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

  function add(kind:Int, dims:Array<Int>, ?options:FieldPlacementOptions, ?chunkSizeOverride:Int):FieldsBuilder {
    ensureMutable();
    var checkedDims = TensorStorage.validateShape(dims);
    var chunkSize = chunkSizeOverride != null
      ? chunkSizeOverride
      : options != null && options.chunkSize != null ? options.chunkSize : DEFAULT_DYNAMIC_CHUNK_SIZE;
    if (chunkSize <= 0) {
      throw "Quadrants field placement chunk size must be positive";
    }
    var order = physicalOrder(checkedDims.length, options);
    var axisBase = shape.length;
    var axes = [for (axis in order) axisBase + axis];
    var sizes = [for (axis in order) checkedDims[axis]];
    steps.push({kind: kind, axes: axes, sizes: sizes, chunkSize: chunkSize});
    for (dim in checkedDims) {
      shape.push(dim);
    }
    if (options != null && options.offset != null) {
      placementOffset = [for (value in options.offset) value];
    }
    return this;
  }

  public function dense(dims:Array<Int>, ?options:FieldPlacementOptions):FieldsBuilder {
    return add(SNODE_DENSE, dims, options);
  }

  public function pointer(dims:Array<Int>, ?options:FieldPlacementOptions):FieldsBuilder {
    return add(SNODE_POINTER, dims, options);
  }

  public function bitmasked(dims:Array<Int>, ?options:FieldPlacementOptions):FieldsBuilder {
    return add(SNODE_BITMASKED, dims, options);
  }

  public function dynamicNode(dims:Array<Int>, ?options:FieldPlacementOptions):FieldsBuilder {
    return add(SNODE_DYNAMIC, dims, options);
  }

  public function bitStruct(maxBits:Int):FieldsBuilder {
    ensureMutable();
    if (maxBits <= 0 || maxBits > 64) {
      throw "Quadrants bitStruct maxBits must be in 1...64";
    }
    steps.push({kind: SNODE_BIT_STRUCT, axes: [], sizes: [], chunkSize: maxBits});
    return this;
  }

  public function quantArray(dims:Array<Int>, maxNumBits:quadrants.quant.QuantBits, ?options:FieldPlacementOptions):FieldsBuilder {
    return add(SNODE_QUANT_ARRAY, dims, options, maxNumBits);
  }

  public function offset(offset:Array<Int>):FieldsBuilder {
    ensureMutable();
    if (offset == null) {
      throw "Quadrants field placement offset is required";
    }
    placementOffset = [for (value in offset) value];
    for (value in placementOffset) {
      if (value < 0) {
        throw "Quadrants field placement offset values must be non-negative";
      }
    }
    return this;
  }

  static function identityOrder(rank:Int):Array<Int> {
    return [for (axis in 0...rank) axis];
  }

  static function physicalOrder(rank:Int, ?options:FieldPlacementOptions):Array<Int> {
    var order = if (options != null && options.order != null) {
      [for (axis in options.order) axis];
    } else if (options != null && options.layout != null && options.layout.order.length > 0) {
      [for (axis in options.layout.order) axis];
    } else if (options != null && options.layout != null && options.layout.policy == LayoutPolicy.ColumnMajor) {
      [for (i in 0...rank) rank - 1 - i];
    } else {
      identityOrder(rank);
    }
    validateOrder(rank, order);
    return order;
  }

  static function validateOrder(rank:Int, order:Array<Int>):Void {
    if (order.length != rank) {
      throw 'Quadrants field placement order rank must match shape rank (order=${order.length}, shape=${rank})';
    }
    var seen = [for (_ in 0...rank) false];
    for (axis in order) {
      if (axis < 0 || axis >= rank || seen[axis]) {
        throw "Quadrants field placement order must be a permutation of 0...rank";
      }
      seen[axis] = true;
    }
  }

  public static function validatePlacementOffset(shape:Array<Int>, offset:Null<Array<Int>>):Array<Int> {
    if (offset == null || offset.length == 0) {
      return [];
    }
    if (offset.length != shape.length) {
      throw 'Quadrants field placement offset rank must match field shape rank (offset=${offset.length}, shape=${shape.length})';
    }
    var result = [for (value in offset) value];
    for (value in result) {
      if (value < 0) {
        throw "Quadrants field placement offset values must be non-negative";
      }
    }
    return result;
  }

  static function copySteps(steps:Array<FieldPlacementStep>):Array<FieldPlacementStep> {
    return [for (step in steps) {kind: step.kind, axes: [for (axis in step.axes) axis], sizes: [for (size in step.sizes) size], chunkSize: step.chunkSize}];
  }

  static function validateStepsMatchShape(shape:Array<Int>, steps:Array<FieldPlacementStep>):Void {
    var seen = [for (_ in 0...shape.length) false];
    for (step in steps) {
      if (step.kind == SNODE_BIT_STRUCT) {
        if (step.axes.length != 0 || step.sizes.length != 0) {
          throw "Quadrants bitStruct placement step must not declare axes";
        }
        continue;
      }
      if (step.axes.length == 0 || step.axes.length != step.sizes.length) {
        throw "Quadrants field placement step axes/sizes rank mismatch";
      }
      if (step.chunkSize <= 0) {
        throw "Quadrants field placement chunk size must be positive";
      }
      for (i in 0...step.axes.length) {
        var axis = step.axes[i];
        if (axis < 0 || axis >= shape.length || seen[axis]) {
          throw "Quadrants field placement axes must cover each logical shape axis exactly once";
        }
        if (step.sizes[i] != shape[axis]) {
          throw "Quadrants field placement step size must match field shape";
        }
        seen[axis] = true;
      }
    }
    for (axis in 0...seen.length) {
      if (!seen[axis]) {
        throw "Quadrants field placement axes must cover each logical shape axis exactly once";
      }
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
        TensorStorage.nativeIntArray(step.axes),
        TensorStorage.nativeIntArray(step.sizes),
        step.chunkSize
      );
    }
    return current;
  }

  public static function placeDense(context:Context, field:FieldRuntime, shape:Array<Int>):Void {
    var checkedShape = TensorStorage.validateShape(shape);
    var denseSteps = [{kind: SNODE_DENSE, axes: identityOrder(checkedShape.length), sizes: [for (dim in checkedShape) dim], chunkSize: DEFAULT_DYNAMIC_CHUNK_SIZE}];
    placeWithSteps(context, field, checkedShape, denseSteps);
  }

  public static function placeWithSteps(context:Context, field:FieldRuntime, shape:Array<Int>, steps:Array<FieldPlacementStep>, ?offset:Array<Int>):Void {
    field.ensurePlaceable();
    var checkedShape = TensorStorage.validateShape(shape);
    var checkedSteps = copySteps(steps);
    validateStepsMatchShape(checkedShape, checkedSteps);
    var checkedOffset = validatePlacementOffset(checkedShape, offset);
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
      var snodeId = checkedOffset.length == 0
        ? Native.snode_tree_place(tree, parent, field.dtype, name)
        : Native.snode_tree_place_with_offset(tree, parent, field.dtype, TensorStorage.nativeIntArray(checkedOffset), name);
      var treeId = Native.snode_tree_commit(context.nativeHandle(), tree);
      field.placeSNode(quadrants.TensorStorage.copyIntArray(checkedShape), snodeId, treeId, checkedSteps, checkedOffset);
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
      spec:quadrants.quant.QuantStorageSpec<T>,
      ?offset:Array<Int>):Void {
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
    var checkedOffset = validatePlacementOffset(checkedShape, offset);
    if (!hasQuantArrayStep(checkedSteps) && !hasBitStructStep(checkedSteps)) {
      throw "Quadrants placeQuant requires a quantArray or bitStruct placement step";
    }
    for (step in checkedSteps) {
      if ((step.kind == SNODE_QUANT_ARRAY || step.kind == SNODE_BIT_STRUCT) && spec.bits > step.chunkSize) {
        throw "Quadrants quant spec bit width exceeds quant placement maxNumBits";
      }
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
            TensorStorage.nativeIntArray(step.axes),
            TensorStorage.nativeIntArray(step.sizes),
            step.chunkSize
          );
        }
      }
      var name = @:privateAccess "".toUtf8();
      var snodeId = checkedOffset.length == 0
        ? Native.snode_tree_place_quant(
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
        )
        : Native.snode_tree_place_quant_with_offset(
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
          TensorStorage.nativeIntArray(checkedOffset),
          name
        );
      var treeId = Native.snode_tree_commit(context.nativeHandle(), tree);
      runtime.placeSNode(quadrants.TensorStorage.copyIntArray(checkedShape), snodeId, treeId, checkedSteps, checkedOffset);
    } catch (e:Dynamic) {
      Native.snode_tree_close(tree);
      throw e;
    }
    Native.snode_tree_close(tree);
  }

  public function path():quadrants.snode.FieldPlacementPath {
    ensureHasSteps();
    return new quadrants.snode.FieldPlacementPath(context, quadrants.TensorStorage.copyIntArray(shape), copySteps(steps), placementOffset);
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

  public function destroy():Void {
    steps = [];
    shape = [];
    placementOffset = null;
    finalized = false;
  }
}
