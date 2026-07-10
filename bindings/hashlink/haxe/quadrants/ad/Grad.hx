package quadrants.ad;

import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.Native;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;

class Grad {
  public static function zeroGrad(value:Dynamic):Void {
    zeroPeer(value, "grad");
  }

  public static function zeroDual(value:Dynamic):Void {
    zeroPeer(value, "dual");
  }

  public static function zeroTensorGrad<T>(value:Tensor<T>):Void {
    zeroPeer(value, "grad");
  }

  public static function zeroFieldGrad<T>(value:Field<T>):Void {
    zeroPeer(value, "grad");
  }

  public static function zeroTensorDual<T>(value:Tensor<T>):Void {
    zeroPeer(value, "dual");
  }

  public static function zeroFieldDual<T>(value:Field<T>):Void {
    zeroPeer(value, "dual");
  }

  public static function seedTensorGrad<T>(value:Tensor<T>, seed:Float = 1.0):Void {
    seedTensorPeer(value, seed, "grad", "Grad.seedTensorGrad");
  }

  public static function seedFieldGrad<T>(value:Field<T>, seed:Float = 1.0):Void {
    seedFieldPeer(value, seed, "grad", "Grad.seedFieldGrad");
  }

  public static function seedTensorDual<T>(value:Tensor<T>, seed:Float = 1.0):Void {
    seedTensorPeer(value, seed, "dual", "Grad.seedTensorDual");
  }

  public static function seedFieldDual<T>(value:Field<T>, seed:Float = 1.0):Void {
    seedFieldPeer(value, seed, "dual", "Grad.seedFieldDual");
  }

  public static function clearAllGradients(...values:Dynamic):Void {
    if (values.length == 0) {
      throw "Quadrants Grad.clearAllGradients requires at least one value";
    }
    for (value in values) {
      zeroGrad(value);
    }
  }

  @:allow(quadrants.Tape)
  @:allow(quadrants.ad.GradCheck)
  static function supportsAutodiff(value:Dynamic):Bool {
    if (!Std.isOfType(value, TensorRuntime) && !Std.isOfType(value, FieldRuntime)) {
      return false;
    }
    return switch (dtypeOf(value)) {
      case DType.F16 | DType.F32 | DType.F64:
        true;
      default:
        false;
    };
  }

  @:allow(quadrants.ad.FwdMode)
  @:allow(quadrants.ad.GradCheck)
  static function writeTensorReal<T>(value:Tensor<T>, flatIndex:Int, realValue:Float, operation:String):Void {
    writeFloatingTensor(tensorRuntime(value, operation, operation), flatIndex, realValue);
  }

  @:allow(quadrants.ad.GradCheck)
  static function readTensorReal<T>(value:Tensor<T>, flatIndex:Int, operation:String):Float {
    return readFloatingTensor(tensorRuntime(value, operation, operation), flatIndex);
  }

  @:allow(quadrants.ad.GradCheck)
  static function fillTensorReal<T>(value:Tensor<T>, realValue:Float, operation:String):Void {
    fillFloatingTensor(tensorRuntime(value, operation, operation), realValue);
  }

  @:allow(quadrants.ad.GradCheck)
  static function enableTensorGrad<T>(value:Tensor<T>, operation:String):Void {
    var tensor = tensorRuntime(value, operation, "grad");
    tensor.enableGradFlag(true);
    peerStorage(value, "grad");
  }

  @:allow(quadrants.ad.GradCheck)
  static function readFieldReal<T>(value:Field<T>, flatIndex:Int, operation:String):Float {
    return readFloatingField(fieldRuntime(value, operation, operation), flatIndex);
  }

  @:allow(quadrants.ad.GradCheck)
  static function writeFieldReal<T>(value:Field<T>, flatIndex:Int, realValue:Float, operation:String):Void {
    writeFloatingField(fieldRuntime(value, operation, operation), flatIndex, realValue);
  }

  @:allow(quadrants.ad.GradCheck)
  static function fillFieldReal<T>(value:Field<T>, realValue:Float, operation:String):Void {
    fillFloatingField(fieldRuntime(value, operation, operation), realValue);
  }

  @:allow(quadrants.ad.GradCheck)
  static function enableFieldGrad<T>(value:Field<T>, operation:String):Void {
    fieldRuntime(value, operation, "grad");
    peerStorage(value, "grad");
  }

  static function zeroPeer(value:Dynamic, peerName:String):Void {
    if (value == null) {
      throw 'Quadrants Grad.${peerName} zeroing requires a tensor or field';
    }
    var dtype = dtypeOf(value);
    requireAutodiffDType(value, peerName);
    if (Std.isOfType(value, FieldRuntime)) {
      var field:FieldRuntime = cast value;
      if (field.shape == null) {
        throw 'Quadrants cannot zero ${peerName} storage for an unplaced field';
      }
    }
    fillFloatingStorage(peerStorage(value, peerName), dtype, peerName, 0.0);
  }

  static function seedTensorPeer<T>(value:Tensor<T>, seed:Float, peerName:String, operation:String):Void {
    var tensor = tensorRuntime(value, operation, peerName);
    tensor.enableGradFlag(true);
    fillFloatingStorage(peerStorage(value, peerName), tensor.dtype, peerName, seed);
  }

  static function seedFieldPeer<T>(value:Field<T>, seed:Float, peerName:String, operation:String):Void {
    var field = fieldRuntime(value, operation, peerName);
    fillFloatingStorage(peerStorage(value, peerName), field.dtype, peerName, seed);
  }

  static function tensorRuntime<T>(value:Tensor<T>, operation:String, peerName:String):TensorRuntime {
    if (value == null) {
      throw 'Quadrants ${operation} requires a tensor';
    }
    var tensor:TensorRuntime = cast value;
    tensor.requireAutodiffDType(peerName);
    return tensor;
  }

  static function fieldRuntime<T>(value:Field<T>, operation:String, peerName:String):FieldRuntime {
    if (value == null) {
      throw 'Quadrants ${operation} requires a field';
    }
    var field:FieldRuntime = cast value;
    field.requireAutodiffDType(peerName);
    if (field.shape == null) {
      throw 'Quadrants ${operation} requires a placed field';
    }
    return field;
  }

  static function peerStorage(value:Dynamic, peerName:String):Dynamic {
    var peer = Reflect.getProperty(value, peerName);
    if (peer == null) {
      throw 'Quadrants value did not expose ${peerName} storage';
    }
    return peer;
  }

  static function dtypeOf(value:Dynamic):DType {
    if (Std.isOfType(value, TensorRuntime)) {
      return (cast value : TensorRuntime).dtype;
    }
    if (Std.isOfType(value, FieldRuntime)) {
      return (cast value : FieldRuntime).dtype;
    }
    throw "Quadrants Grad utilities require Tensor or Field values";
  }

  static function requireAutodiffDType(value:Dynamic, peerName:String):Void {
    if (Std.isOfType(value, TensorRuntime)) {
      (cast value : TensorRuntime).requireAutodiffDType(peerName);
      return;
    }
    if (Std.isOfType(value, FieldRuntime)) {
      (cast value : FieldRuntime).requireAutodiffDType(peerName);
      return;
    }
    throw "Quadrants Grad utilities require Tensor or Field values";
  }

  static function fillFloatingStorage(storage:Dynamic, dtype:DType, peerName:String, value:Float):Void {
    if (Std.isOfType(storage, TensorRuntime)) {
      var tensor:TensorRuntime = cast storage;
      if (tensor.dtype != dtype) {
        throw 'Quadrants ${peerName} storage dtype does not match its primal';
      }
      fillFloatingTensor(tensor, value);
      return;
    }
    if (Std.isOfType(storage, FieldRuntime)) {
      var field:FieldRuntime = cast storage;
      if (field.dtype != dtype) {
        throw 'Quadrants ${peerName} storage dtype does not match its primal';
      }
      fillFloatingField(field, value);
      return;
    }
    throw 'Quadrants ${peerName} storage is not a Tensor or Field';
  }

  static function readFloatingTensor(tensor:TensorRuntime, flatIndex:Int):Float {
    var ctx = tensor.context.nativeHandle();
    var arr = tensor.nativeHandle();
    return switch (tensor.dtype) {
      case DType.F16:
        Native.ndarray_read_f16(ctx, arr, flatIndex);
      case DType.F32:
        Native.ndarray_read_f32(ctx, arr, flatIndex);
      case DType.F64:
        Native.ndarray_read_f64(ctx, arr, flatIndex);
      default:
        throw 'Quadrants real host read requires an autodiff dtype; ${tensor.dtype} is unsupported';
    };
  }

  static function writeFloatingTensor(tensor:TensorRuntime, flatIndex:Int, value:Float):Void {
    var ctx = tensor.context.nativeHandle();
    var arr = tensor.nativeHandle();
    switch (tensor.dtype) {
      case DType.F16:
        Native.ndarray_write_f16(ctx, arr, flatIndex, value);
      case DType.F32:
        Native.ndarray_write_f32(ctx, arr, flatIndex, value);
      case DType.F64:
        Native.ndarray_write_f64(ctx, arr, flatIndex, value);
      default:
        throw 'Quadrants real host write requires an autodiff dtype; ${tensor.dtype} is unsupported';
    }
  }

  static function fillFloatingTensor(tensor:TensorRuntime, value:Float):Void {
    var ctx = tensor.context.nativeHandle();
    var arr = tensor.nativeHandle();
    switch (tensor.dtype) {
      case DType.F16:
        Native.ndarray_fill_f16(ctx, arr, value);
      case DType.F32:
        Native.ndarray_fill_f32(ctx, arr, value);
      case DType.F64:
        Native.ndarray_fill_f64(ctx, arr, value);
      default:
        throw 'Quadrants real host fill requires an autodiff dtype; ${tensor.dtype} is unsupported';
    }
  }

  static function readFloatingField(field:FieldRuntime, flatIndex:Int):Float {
    if (!field.hasSNode()) {
      return readFloatingTensor(cast field.requireTensor(), flatIndex);
    }
    var ctx = field.context.nativeHandle();
    var indices = field.nativeIndices(flatIndex);
    return switch (field.dtype) {
      case DType.F16:
        Native.snode_read_f16(ctx, field.snodeId, indices);
      case DType.F32:
        Native.snode_read_f32(ctx, field.snodeId, indices);
      case DType.F64:
        Native.snode_read_f64(ctx, field.snodeId, indices);
      default:
        throw 'Quadrants real host read requires an autodiff dtype; ${field.dtype} is unsupported';
    };
  }

  static function writeFloatingField(field:FieldRuntime, flatIndex:Int, value:Float):Void {
    if (!field.hasSNode()) {
      writeFloatingTensor(cast field.requireTensor(), flatIndex, value);
      return;
    }
    var ctx = field.context.nativeHandle();
    var indices = field.nativeIndices(flatIndex);
    switch (field.dtype) {
      case DType.F16:
        Native.snode_write_f16(ctx, field.snodeId, indices, value);
      case DType.F32:
        Native.snode_write_f32(ctx, field.snodeId, indices, value);
      case DType.F64:
        Native.snode_write_f64(ctx, field.snodeId, indices, value);
      default:
        throw 'Quadrants real host write requires an autodiff dtype; ${field.dtype} is unsupported';
    }
  }

  static function fillFloatingField(field:FieldRuntime, value:Float):Void {
    if (field.shape == null) {
      throw "Quadrants cannot fill autodiff storage for an unplaced field";
    }
    if (!field.hasSNode()) {
      fillFloatingTensor(cast field.requireTensor(), value);
      return;
    }
    var ctx = field.context.nativeHandle();
    switch (field.dtype) {
      case DType.F16:
        Native.snode_fill_f16(ctx, field.snodeId, value);
      case DType.F32:
        Native.snode_fill_f32(ctx, field.snodeId, value);
      case DType.F64:
        Native.snode_fill_f64(ctx, field.snodeId, value);
      default:
        throw 'Quadrants real host fill requires an autodiff dtype; ${field.dtype} is unsupported';
    }
  }
}
