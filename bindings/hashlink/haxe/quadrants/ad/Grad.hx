package quadrants.ad;

import haxe.Int64;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.Native;
import quadrants.Tensor;
import quadrants.TensorRuntime;
import quadrants.Types.DType;
import quadrants.Types.F32;

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

  public static function seedTensorGrad(value:Tensor<F32>, seed:Float = 1.0):Void {
    if (value == null) {
      throw "Quadrants Grad.seedTensorGrad requires an F32 tensor";
    }
    value.enableGrad();
    value.grad.fill(seed);
  }

  public static function seedFieldGrad(value:Field<F32>, seed:Float = 1.0):Void {
    if (value == null) {
      throw "Quadrants Grad.seedFieldGrad requires an F32 field";
    }
    value.grad.fill(seed);
  }

  public static function seedTensorDual(value:Tensor<F32>, seed:Float = 1.0):Void {
    if (value == null) {
      throw "Quadrants Grad.seedTensorDual requires an F32 tensor";
    }
    value.enableGrad();
    value.dual.fill(seed);
  }

  public static function seedFieldDual(value:Field<F32>, seed:Float = 1.0):Void {
    if (value == null) {
      throw "Quadrants Grad.seedFieldDual requires an F32 field";
    }
    value.dual.fill(seed);
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
    if (Std.isOfType(storage, TensorRuntime)) {
      fillTensor(cast storage, dtype);
      return;
    }
    if (Std.isOfType(storage, FieldRuntime)) {
      fillField(cast storage, dtype, peerName);
      return;
    }
    var fill = Reflect.field(storage, "fill");
    if (fill == null) {
      throw 'Quadrants ${peerName} storage does not expose fill(value)';
    }
    Reflect.callMethod(storage, fill, [zeroValue(dtype)]);
  }

  static function fillTensor(tensor:TensorRuntime, dtype:DType):Void {
    var ctx = tensor.context.nativeHandle();
    var arr = tensor.nativeHandle();
    switch (dtype) {
      case DType.I8:
        Native.ndarray_fill_i8(ctx, arr, 0);
      case DType.I16:
        Native.ndarray_fill_i16(ctx, arr, 0);
      case DType.I32:
        Native.ndarray_fill_i32(ctx, arr, 0);
      case DType.I64:
        Native.ndarray_fill_i64(ctx, arr, Int64.make(0, 0));
      case DType.U8:
        Native.ndarray_fill_u8(ctx, arr, 0);
      case DType.U16:
        Native.ndarray_fill_u16(ctx, arr, 0);
      case DType.U32:
        Native.ndarray_fill_u32(ctx, arr, Int64.make(0, 0));
      case DType.U64:
        Native.ndarray_fill_u64(ctx, arr, Int64.make(0, 0));
      case DType.U1:
        Native.ndarray_fill_u1(ctx, arr, 0);
      case DType.F16:
        Native.ndarray_fill_f16(ctx, arr, 0.0);
      case DType.F32:
        Native.ndarray_fill_f32(ctx, arr, 0.0);
      case DType.F64:
        Native.ndarray_fill_f64(ctx, arr, 0.0);
    }
  }

  static function fillField(field:FieldRuntime, dtype:DType, peerName:String):Void {
    if (field.shape == null) {
      throw 'Quadrants cannot zero ${peerName} storage for an unplaced field';
    }
    if (!field.hasSNode()) {
      fillTensor(cast field.requireTensor(), dtype);
      return;
    }
    var ctx = field.context.nativeHandle();
    switch (dtype) {
      case DType.I8:
        Native.snode_fill_i8(ctx, field.snodeId, 0);
      case DType.I16:
        Native.snode_fill_i16(ctx, field.snodeId, 0);
      case DType.I32:
        Native.snode_fill_i32(ctx, field.snodeId, 0);
      case DType.I64:
        Native.snode_fill_i64(ctx, field.snodeId, Int64.make(0, 0));
      case DType.U8:
        Native.snode_fill_u8(ctx, field.snodeId, 0);
      case DType.U16:
        Native.snode_fill_u16(ctx, field.snodeId, 0);
      case DType.U32:
        Native.snode_fill_u32(ctx, field.snodeId, Int64.make(0, 0));
      case DType.U64:
        Native.snode_fill_u64(ctx, field.snodeId, Int64.make(0, 0));
      case DType.U1:
        Native.snode_fill_u1(ctx, field.snodeId, 0);
      case DType.F16:
        Native.snode_fill_f16(ctx, field.snodeId, 0.0);
      case DType.F32:
        Native.snode_fill_f32(ctx, field.snodeId, 0.0);
      case DType.F64:
        Native.snode_fill_f64(ctx, field.snodeId, 0.0);
    }
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
