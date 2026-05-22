package quadrants;

import quadrants.FieldsBuilder.FieldPlacementStep;
import quadrants.Native.QNdarray;
import quadrants.Types.DType;

typedef TensorFactory = Array<Int>->TensorHandle;

class FieldRuntime implements TensorHandle {
  public final context:Context;
  public final dtype:DType;
  public var shape(default, null):Array<Int> = null;
  public var tensor:Dynamic = null;
  public var gradField:Dynamic = null;
  public var dualField:Dynamic = null;
  public var ownsTensor:Bool = false;
  public var snodeId(default, null):Int = -1;
  public var snodeTreeId(default, null):Int = -1;
  public var closed:Bool = false;
  final tensorFactory:TensorFactory;
  var placementSteps:Array<FieldPlacementStep> = null;

  public function new(context:Context, dtype:DType, tensorFactory:TensorFactory, ?shape:Array<Int>) {
    this.context = context;
    this.dtype = dtype;
    this.tensorFactory = tensorFactory;
    if (shape != null) {
      place(shape);
    }
  }

  public function ensureOpen():Void {
    if (closed) {
      throw "Quadrants field is closed";
    }
  }

  public function ensurePlaceable():Void {
    ensureOpen();
    if (tensor != null || snodeId >= 0) {
      throw "Quadrants field is already placed";
    }
  }

  public function place(shape:Array<Int>):Void {
    FieldsBuilder.placeDense(context, this, shape);
  }

  public function placeSNode(shape:Array<Int>, snodeId:Int, snodeTreeId:Int, steps:Array<FieldPlacementStep>):Void {
    ensurePlaceable();
    this.shape = TensorStorage.validateShape(shape);
    this.tensor = null;
    this.snodeId = snodeId;
    this.snodeTreeId = snodeTreeId;
    this.placementSteps = [for (step in steps) {kind: step.kind, axis: step.axis, size: step.size, chunkSize: step.chunkSize}];
    gradField = null;
    dualField = null;
    ownsTensor = false;
  }

  public function copyPlacementSteps():Array<FieldPlacementStep> {
    if (placementSteps == null) {
      throw "Quadrants field has no placement steps";
    }
    return [for (step in placementSteps) {kind: step.kind, axis: step.axis, size: step.size, chunkSize: step.chunkSize}];
  }

  public function placeCloneOf(source:FieldRuntime):Void {
    FieldsBuilder.placeWithSteps(context, this, quadrants.TensorStorage.copyIntArray(source.shape), source.copyPlacementSteps());
  }

  public function setTensor(source:TensorHandle, owns:Bool):Void {
    ensureOpen();
    if (source.context != context) {
      throw "Quadrants field source tensor belongs to a different context";
    }
    if (source.dtype != dtype) {
      throw "Quadrants field source tensor dtype mismatch";
    }
    tensor = source;
    shape = quadrants.TensorStorage.copyIntArray(source.shape);
    gradField = null;
    dualField = null;
    ownsTensor = owns;
    snodeId = -1;
    snodeTreeId = -1;
    placementSteps = null;
  }

  public function copyFromTensor(source:TensorHandle):Void {
    ensureOpen();
    if (source.context != context) {
      throw "Quadrants field source tensor belongs to a different context";
    }
    if (source.dtype != dtype) {
      throw "Quadrants field source tensor dtype mismatch";
    }
    if (hasSNode()) {
      TensorStorage.requireSameShape(shape, source.shape, "field source tensor");
      tensor = source;
      ownsTensor = false;
      syncTensorToSNode();
      tensor = null;
      gradField = null;
      dualField = null;
      return;
    }
    setTensor(source, false);
  }

  public function requireTensor():TensorHandle {
    ensureOpen();
    if (tensor == null) {
      throw "Quadrants field has not been placed";
    }
    return cast tensor;
  }

  public function hasSNode():Bool {
    ensureOpen();
    return snodeId >= 0;
  }

  public function elementCount():Int {
    ensureOpen();
    if (shape == null) {
      throw "Quadrants field has not been placed";
    }
    return TensorStorage.elementCount(shape);
  }

  public function nativeIndices(flatIndex:Int):hl.NativeArray<Int> {
    ensureOpen();
    if (shape == null) {
      throw "Quadrants field has not been placed";
    }
    return TensorStorage.nativeIntArray(TensorStorage.indicesFromFlat(shape, flatIndex));
  }

  function ensureTensorMirror():TensorHandle {
    ensureOpen();
    if (tensor == null) {
      if (shape == null) {
        throw "Quadrants field has not been placed";
      }
      tensor = tensorFactory(quadrants.TensorStorage.copyIntArray(shape));
      ownsTensor = true;
    }
    return cast tensor;
  }

  public function syncSNodeToTensor():Void {
    if (!hasSNode()) {
      return;
    }
    var target = ensureTensorMirror();
    Native.snode_copy_to_ndarray(context.nativeHandle(), snodeId, dtype, target.nativeHandle());
  }

  public function syncTensorToSNode():Void {
    if (!hasSNode() || tensor == null) {
      return;
    }
    var source:TensorHandle = cast tensor;
    Native.snode_copy_from_ndarray(context.nativeHandle(), snodeId, dtype, source.nativeHandle());
  }

  public function refreshAutodiffPeerHandles():Void {
    ensureOpen();
    var primal = nativeHandle();
    if (gradField != null) {
      Native.ndarray_set_grad_handle(primal, (cast gradField : FieldRuntime).nativeHandle());
    }
    if (dualField != null) {
      Native.ndarray_set_dual_handle(primal, (cast dualField : FieldRuntime).nativeHandle());
    }
  }

  public function syncAutodiffPeersToTensor():Void {
    ensureOpen();
    if (gradField != null) {
      (cast gradField : FieldRuntime).syncSNodeToTensor();
    }
    if (dualField != null) {
      (cast dualField : FieldRuntime).syncSNodeToTensor();
    }
    refreshAutodiffPeerHandles();
  }

  public function syncAutodiffPeersFromTensor():Void {
    ensureOpen();
    if (gradField != null) {
      (cast gradField : FieldRuntime).syncTensorToSNode();
    }
    if (dualField != null) {
      (cast dualField : FieldRuntime).syncTensorToSNode();
    }
  }

  public function nativeHandle():QNdarray {
    return ensureTensorMirror().nativeHandle();
  }

  public function close():Void {
    if (closed) {
      return;
    }
    if (gradField != null) {
      (cast gradField : FieldRuntime).close();
      gradField = null;
    }
    if (dualField != null) {
      (cast dualField : FieldRuntime).close();
      dualField = null;
    }
    if (ownsTensor && tensor != null) {
      (cast tensor : TensorHandle).close();
    }
    tensor = null;
    shape = null;
    snodeId = -1;
    snodeTreeId = -1;
    placementSteps = null;
    closed = true;
  }
}
