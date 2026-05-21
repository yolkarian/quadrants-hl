package quadrants;

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

  public function placeSNode(shape:Array<Int>, snodeId:Int, snodeTreeId:Int):Void {
    ensurePlaceable();
    this.shape = TensorStorage.validateShape(shape);
    this.snodeId = snodeId;
    this.snodeTreeId = snodeTreeId;
    gradField = null;
    dualField = null;
    ownsTensor = false;
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
    shape = source.shape;
    gradField = null;
    dualField = null;
    ownsTensor = owns;
    snodeId = -1;
    snodeTreeId = -1;
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
      tensor = tensorFactory(shape.copy());
      ownsTensor = true;
    }
    return cast tensor;
  }

  public function syncSNodeToTensor():Void {
    if (!hasSNode()) {
      return;
    }
    var target = ensureTensorMirror();
    var readField = Reflect.field(this, "read");
    var writeTensor = Reflect.field(target, "write");
    for (i in 0...elementCount()) {
      Reflect.callMethod(target, writeTensor, [i, Reflect.callMethod(this, readField, [i])]);
    }
  }

  public function syncTensorToSNode():Void {
    if (!hasSNode() || tensor == null) {
      return;
    }
    var source:TensorHandle = cast tensor;
    var readTensor = Reflect.field(source, "read");
    var writeField = Reflect.field(this, "write");
    for (i in 0...elementCount()) {
      Reflect.callMethod(this, writeField, [i, Reflect.callMethod(source, readTensor, [i])]);
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
    closed = true;
  }
}
