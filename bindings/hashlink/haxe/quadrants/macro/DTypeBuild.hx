package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

typedef DTypeSpecData = {
  var typeName:String;
  var suffix:String;
  var nativeValueType:ComplexType;
}

class DTypeBuild {
  public static final generatedPack:Array<String> = ["quadrants", "_generated"];

  public static function fromLocalType(facadeName:String):DTypeSpecData {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => cls, params) if (cls.name == facadeName && cls.pack.join(".") == "quadrants"):
        if (params.length != 1) {
          Context.error('quadrants.${facadeName} requires exactly one dtype type parameter', Context.currentPos());
        }
        fromType(params[0]);
      default:
        Context.error('quadrants.${facadeName} generic build expected a ${facadeName}<T> local type', Context.currentPos());
    };
  }

  public static function fromType(type:Type):DTypeSpecData {
    return switch (type) {
      case TAbstract(absRef, _):
        fromTypeName(absRef.get().name, Context.currentPos());
      case TInst(clsRef, _):
        fromTypeName(clsRef.get().name, Context.currentPos());
      case TType(typeRef, params):
        fromType(typeRef.get().type);
      case TLazy(f):
        fromType(f());
      default:
        Context.error("Quadrants Tensor type parameter must be one of quadrants.Types.I8/I16/I32/I64/U8/U16/U32/U64/U1/F16/F32/F64", Context.currentPos());
    };
  }

  public static function fromTypeName(typeName:String, pos:Position):DTypeSpecData {
    return switch (typeName) {
      case "I8": spec("I8", "i8", macro : Int);
      case "I16": spec("I16", "i16", macro : Int);
      case "I32": spec("I32", "i32", macro : Int);
      case "I64": spec("I64", "i64", macro : haxe.Int64);
      case "U8": spec("U8", "u8", macro : Int);
      case "U16": spec("U16", "u16", macro : Int);
      case "U32": spec("U32", "u32", macro : haxe.Int64);
      case "U64": spec("U64", "u64", macro : haxe.Int64);
      case "U1": spec("U1", "u1", macro : Int);
      case "F16": spec("F16", "f16", macro : Float);
      case "F32": spec("F32", "f32", macro : Float);
      case "F64": spec("F64", "f64", macro : Float);
      default:
        Context.error('Unsupported Quadrants Tensor dtype ${typeName}', pos);
    };
  }

  static function spec(typeName:String, suffix:String, nativeValueType:ComplexType):DTypeSpecData {
    return {typeName: typeName, suffix: suffix, nativeValueType: nativeValueType};
  }

  public static function dtypeComplexType(typeName:String):ComplexType {
    return TPath({pack: ["quadrants"], name: "Types", sub: typeName});
  }

  public static function dtypeExpr(typeName:String, pos:Position):Expr {
    return Context.parse('quadrants.Types.DType.${typeName}', pos);
  }

  public static function tensorClassName(typeName:String):String {
    return 'Tensor_${typeName}';
  }

  public static function fieldClassName(typeName:String):String {
    return 'Field_${typeName}';
  }

  public static function generatedTypePath(name:String):TypePath {
    return {pack: generatedPack, name: name};
  }

  public static function generatedComplexType(name:String):ComplexType {
    return TPath(generatedTypePath(name));
  }

  public static function typeParam(ct:ComplexType):TypeParam {
    return TPType(ct);
  }

  public static function bufferViewComplexType(valueType:ComplexType):ComplexType {
    return TPath({pack: ["quadrants"], name: "BufferView", params: [TPType(valueType)]});
  }

  public static function arrayComplexType(valueType:ComplexType):ComplexType {
    return TPath({pack: [], name: "Array", params: [TPType(valueType)]});
  }

  public static function arg(name:String, type:ComplexType, ?value:Expr, opt:Bool = false):FunctionArg {
    return {name: name, opt: opt, type: type, value: value, meta: []};
  }

  public static function field(name:String, access:Array<Access>, kind:FieldType, pos:Position):Field {
    return {name: name, access: access, kind: kind, pos: pos, meta: []};
  }

  public static function fn(args:Array<FunctionArg>, ret:ComplexType, body:Expr):FieldType {
    return FFun({args: args, ret: ret, expr: body, params: []});
  }

  public static function voidType():ComplexType return macro : Void;
  public static function intType():ComplexType return macro : Int;
  public static function boolType():ComplexType return macro : Bool;
  public static function contextType():ComplexType return macro : quadrants.Context;
  public static function tensorRuntimeType():ComplexType return macro : quadrants.TensorRuntime;
  public static function fieldRuntimeType():ComplexType return macro : quadrants.FieldRuntime;
  public static function tensorHandleType():ComplexType return macro : quadrants.TensorHandle;
}
#end
