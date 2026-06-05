package quadrants.ad;

import haxe.Int64;
import quadrants.FieldRuntime;
import quadrants.TensorRuntime;
import quadrants.Types.DType;

class Grad {
  public static function zeroGrad(value:Dynamic):Void {
    zeroPeer(value, "grad");
  }

  public static function zeroDual(value:Dynamic):Void {
    zeroPeer(value, "dual");
  }

  public static function clearAllGradients(...values:Dynamic):Void {
    if (values.length == 0) {
      throw "Quadrants Grad.clearAllGradients requires at least one value";
    }
    for (value in values) {
      zeroGrad(value);
    }
  }

  static function zeroPeer(value:Dynamic, peerName:String):Void {
    if (value == null) {
      throw 'Quadrants Grad.${peerName} zeroing requires a tensor or field';
    }
    var dtype = dtypeOf(value);
    if (Std.isOfType(value, FieldRuntime)) {
      var field:FieldRuntime = cast value;
      if (field.shape == null) {
        throw 'Quadrants cannot zero ${peerName} storage for an unplaced field';
      }
    }
    var peer = Reflect.getProperty(value, peerName);
    if (peer == null) {
      throw 'Quadrants value did not expose ${peerName} storage';
    }
    fillStorage(peer, dtype, peerName);
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

  static function fillStorage(storage:Dynamic, dtype:DType, peerName:String):Void {
    var fill = Reflect.field(storage, "fill");
    if (fill == null) {
      throw 'Quadrants ${peerName} storage does not expose fill(value)';
    }
    Reflect.callMethod(storage, fill, [zeroValue(dtype)]);
  }

  static function zeroValue(dtype:DType):Dynamic {
    return switch (dtype) {
      case DType.U1: false;
      case DType.I64, DType.U32, DType.U64: Int64.make(0, 0);
      case DType.F16, DType.F32, DType.F64: 0.0;
      case DType.I8, DType.I16, DType.I32, DType.U8, DType.U16: 0;
    };
  }
}
