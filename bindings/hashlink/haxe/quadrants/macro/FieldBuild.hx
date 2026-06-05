package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class FieldBuild {
  static final defined:Map<String, Bool> = new Map();

  public static function build():ComplexType {
    var genericArg = genericFieldArgType();
    if (genericArg != null) {
      return genericArg;
    }
    var spec = DTypeBuild.fromLocalType("Field");
    var className = DTypeBuild.fieldClassName(spec.typeName);
    ensureDefined(spec, className);
    return DTypeBuild.generatedComplexType(className);
  }

  static function genericFieldArgType():Null<ComplexType> {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => cls, params) if (cls.name == "Field" && cls.pack.join(".") == "quadrants"):
        if (params.length != 1) {
          Context.error("quadrants.Field requires exactly one dtype type parameter", Context.currentPos());
        }
        var typeParam = typeParameterComplexType(params[0]);
        typeParam == null ? null : TPath({pack: ["quadrants"], name: "FieldArg", params: [TPType(typeParam)]});
      default:
        null;
    };
  }

  static function typeParameterComplexType(type:Type):Null<ComplexType> {
    return switch (type) {
      case TLazy(f):
        typeParameterComplexType(f());
      case TInst(_.get() => cls, _):
        switch (cls.kind) {
          case KTypeParameter(_):
            TPath({pack: [], name: cls.name});
          default:
            null;
        }
      default:
        null;
    };
  }

  static function ensureDefined(spec, className:String):Void {
    if (defined.exists(className)) {
      return;
    }
    defined[className] = true;

    var pos = Context.currentPos();
    var self = DTypeBuild.generatedComplexType(className);
    var tensorType = TensorBuild.ensureTensor(spec.typeName);
    var valueType = DTypeBuild.dtypeComplexType(spec.typeName);
    var arrayValueType = DTypeBuild.arrayComplexType(valueType);
    var typePathName = 'quadrants.Types.${spec.typeName}';
    var dtype = 'quadrants.Types.DType.${spec.typeName}';
    var tensorClassPath = '${DTypeBuild.generatedPack.join(".")}.${DTypeBuild.tensorClassName(spec.typeName)}';
    var fieldClassPath = '${DTypeBuild.generatedPack.join(".")}.${className}';
    var suffix = spec.suffix;

    var fields:Array<Field> = [];

    function add(name:String, access:Array<Access>, kind:FieldType):Void {
      fields.push(DTypeBuild.field(name, access, kind, pos));
    }

    function fun(args:Array<FunctionArg>, ret:Null<ComplexType>, body:String):FieldType {
      return FFun({args: args, ret: ret, expr: Context.parse(body, pos), params: []});
    }

    add("grad", [APublic], FProp("get", "never", self));
    add("get_grad", [], fun([], self, "return lazyGrad()"));
    add("dual", [APublic], FProp("get", "never", self));
    add("get_dual", [], fun([], self, "return lazyDual()"));

    add("new", [APublic], fun([
      DTypeBuild.arg("context", DTypeBuild.contextType()),
      DTypeBuild.arg("shape", macro : Array<Int>, null, true)
    ], null,
      '{ super(context, ${dtype}, function(shape:Array<Int>):quadrants.TensorHandle return new ${tensorClassPath}(context, shape), shape); }'));

    add("toTensor", [APublic], fun([], tensorType, "{ if (hasSNode()) syncSNodeToTensor(); return cast requireTensor(); }"));

    add("fromTensor", [APublic], fun([
      DTypeBuild.arg("source", tensorType)
    ], DTypeBuild.voidType(), "{ copyFromTensor(source); }"));

    add("lazyGrad", [APublic], fun([], self,
      '{ if (shape == null) throw "Quadrants field has not been placed"; if (gradField == null) { if (hasSNode()) { var created = new ${fieldClassPath}(context); (cast created : quadrants.FieldRuntime).placeCloneOf(this); gradField = created; } else { gradField = new ${fieldClassPath}(context, quadrants.TensorStorage.copyIntArray(shape)); } refreshAutodiffPeerHandles(); } return cast gradField; }'));

    add("lazyDual", [APublic], fun([], self,
      '{ if (shape == null) throw "Quadrants field has not been placed"; if (dualField == null) { if (hasSNode()) { var created = new ${fieldClassPath}(context); (cast created : quadrants.FieldRuntime).placeCloneOf(this); dualField = created; } else { dualField = new ${fieldClassPath}(context, quadrants.TensorStorage.copyIntArray(shape)); } refreshAutodiffPeerHandles(); } return cast dualField; }'));

    add("fill", [APublic], fun([
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), spec.typeName == "U1"
      ? '{ if (hasSNode()) quadrants.Native.snode_fill_${suffix}(context.nativeHandle(), snodeId, ((value : Bool) ? 1 : 0)); else toTensor().fill(value); }'
      : '{ if (hasSNode()) quadrants.Native.snode_fill_${suffix}(context.nativeHandle(), snodeId, cast value); else toTensor().fill(value); }'));

    add("read", [APublic], fun([
      DTypeBuild.arg("flatIndex", DTypeBuild.intType())
    ], valueType, spec.typeName == "U1"
      ? '{ if (hasSNode()) return cast (quadrants.Native.snode_read_${suffix}(context.nativeHandle(), snodeId, nativeIndices(flatIndex)) != 0); return toTensor().read(flatIndex); }'
      : '{ if (hasSNode()) return cast quadrants.Native.snode_read_${suffix}(context.nativeHandle(), snodeId, nativeIndices(flatIndex)); return toTensor().read(flatIndex); }'));

    add("write", [APublic], fun([
      DTypeBuild.arg("flatIndex", DTypeBuild.intType()),
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), spec.typeName == "U1"
      ? '{ if (hasSNode()) quadrants.Native.snode_write_${suffix}(context.nativeHandle(), snodeId, nativeIndices(flatIndex), ((value : Bool) ? 1 : 0)); else toTensor().write(flatIndex, value); }'
      : '{ if (hasSNode()) quadrants.Native.snode_write_${suffix}(context.nativeHandle(), snodeId, nativeIndices(flatIndex), cast value); else toTensor().write(flatIndex, value); }'));

    add("readAt", [APublic], fun([
      DTypeBuild.arg("indices", macro : Array<Int>)
    ], valueType, "{ return read(quadrants.TensorStorage.flatIndex(shape, indices)); }"));

    add("writeAt", [APublic], fun([
      DTypeBuild.arg("indices", macro : Array<Int>),
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), "{ write(quadrants.TensorStorage.flatIndex(shape, indices), value); }"));

    add("toArray", [APublic], fun([], arrayValueType,
      '{ var result = new Array<${typePathName}>(); var count = elementCount(); for (i in 0...count) result.push(read(i)); return result; }'));

    add("fromArray", [APublic], fun([
      DTypeBuild.arg("values", arrayValueType)
    ], DTypeBuild.voidType(),
      '{ quadrants.TensorStorage.requireElementCount(shape, values.length); for (i in 0...values.length) write(i, values[i]); }'));

    Context.defineType({
      pack: DTypeBuild.generatedPack,
      name: className,
      pos: pos,
      meta: [],
      params: [],
      isExtern: false,
      kind: TDClass({pack: ["quadrants"], name: "FieldRuntime"}, [{pack: ["quadrants"], name: "FieldArg", params: [TPType(valueType)]}], false, false, false),
      fields: fields
    });
  }
}
#end
