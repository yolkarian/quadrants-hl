package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class TensorBuild {
  static final defined:Map<String, Bool> = new Map();

  public static function build():ComplexType {
    var genericArg = genericTensorArgType();
    if (genericArg != null) {
      return genericArg;
    }
    var spec = DTypeBuild.fromLocalType("Tensor");
    var className = DTypeBuild.tensorClassName(spec.typeName);
    ensureDefined(spec, className);
    return DTypeBuild.generatedComplexType(className);
  }

  static function genericTensorArgType():Null<ComplexType> {
    return switch (Context.getLocalType()) {
      case TInst(_.get() => cls, params) if (cls.name == "Tensor" && cls.pack.join(".") == "quadrants"):
        if (params.length != 1) {
          Context.error("quadrants.Tensor requires exactly one dtype type parameter", Context.currentPos());
        }
        var typeParam = typeParameterComplexType(params[0]);
        typeParam == null ? null : TPath({pack: ["quadrants"], name: "TensorArg", params: [TPType(typeParam)]});
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

  public static function ensureTensor(typeName:String):ComplexType {
    var spec = DTypeBuild.fromTypeName(typeName, Context.currentPos());
    var className = DTypeBuild.tensorClassName(spec.typeName);
    ensureDefined(spec, className);
    return DTypeBuild.generatedComplexType(className);
  }

  static function ensureDefined(spec, className:String):Void {
    if (defined.exists(className)) {
      return;
    }
    defined[className] = true;

    var pos = Context.currentPos();
    var self = DTypeBuild.generatedComplexType(className);
    var valueType = DTypeBuild.dtypeComplexType(spec.typeName);
    var arrayValueType = DTypeBuild.arrayComplexType(valueType);
    var viewType = DTypeBuild.bufferViewComplexType(valueType);
    var typePathName = 'quadrants.Types.${spec.typeName}';
    var dtype = 'quadrants.Types.DType.${spec.typeName}';
    var classPath = '${DTypeBuild.generatedPack.join(".")}.${className}';
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
      DTypeBuild.arg("shape", macro : Array<Int>),
      DTypeBuild.arg("existingHandle", macro : quadrants.Native.QNdarray, null, true)
    ], null, '{ super(context, ${dtype}, shape, existingHandle); }'));

    add("enableGrad", [APublic], fun([
      DTypeBuild.arg("enabled", DTypeBuild.boolType(), macro true)
    ], self, "{ enableGradFlag(enabled); return this; }"));

    add("lazyGrad", [APublic], fun([], self,
      '{ if (gradTensor == null) { gradTensor = new ${DTypeBuild.generatedPack.join(".")}.${className}(context, quadrants.TensorStorage.copyIntArray(shape)); quadrants.Native.ndarray_set_grad_handle(nativeHandle(), (cast gradTensor).nativeHandle()); } return cast gradTensor; }'));

    add("lazyDual", [APublic], fun([], self,
      '{ if (dualTensor == null) { dualTensor = new ${DTypeBuild.generatedPack.join(".")}.${className}(context, quadrants.TensorStorage.copyIntArray(shape)); quadrants.Native.ndarray_set_dual_handle(nativeHandle(), (cast dualTensor).nativeHandle()); } return cast dualTensor; }'));

    add("fromDLPack", [APublic, AStatic], fun([
      DTypeBuild.arg("context", DTypeBuild.contextType()),
      DTypeBuild.arg("capsule", macro : quadrants.DLPackTensor)
    ], self,
      '{ quadrants.TensorStorage.requireDLPackDType(capsule, ${dtype}); var importedShape = quadrants.TensorStorage.dlpackShape(capsule); quadrants.TensorStorage.requireContiguousDLPack(capsule, importedShape); return new ${classPath}(context, importedShape, quadrants.Native.ndarray_import_dlpack(context.nativeHandle(), ${dtype}, capsule.takeHandle())); }'));

    add("importDLPack", [APublic], fun([
      DTypeBuild.arg("capsule", macro : quadrants.DLPackTensor)
    ], DTypeBuild.voidType(),
      '{ quadrants.TensorStorage.requireDLPackDType(capsule, ${dtype}); var importedShape = quadrants.TensorStorage.dlpackShape(capsule); quadrants.TensorStorage.requireSameShape(shape, importedShape, "DLPack tensor"); quadrants.TensorStorage.requireContiguousDLPack(capsule, importedShape); adoptImportedHandle(quadrants.Native.ndarray_import_dlpack(context.nativeHandle(), ${dtype}, capsule.takeHandle())); }'));

    add("fromExternalPointer", [APublic, AStatic], fun([
      DTypeBuild.arg("context", DTypeBuild.contextType()),
      DTypeBuild.arg("pointer", macro : haxe.Int64),
      DTypeBuild.arg("shape", macro : Array<Int>)
    ], self,
      '{ var checkedShape = quadrants.TensorStorage.validateShape(shape); return new ${classPath}(context, checkedShape, quadrants.Native.ndarray_import_external_pointer(context.nativeHandle(), pointer, ${dtype}, quadrants.TensorStorage.nativeIntArray(checkedShape))); }'));

    add("importExternalPointer", [APublic], fun([
      DTypeBuild.arg("pointer", macro : haxe.Int64)
    ], DTypeBuild.voidType(),
      '{ adoptImportedHandle(quadrants.Native.ndarray_import_external_pointer(context.nativeHandle(), pointer, ${dtype}, quadrants.TensorStorage.nativeIntArray(shape))); }'));

    add("fill", [APublic, AInline], fun([
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), spec.typeName == "U1"
      ? '{ quadrants.Native.ndarray_fill_${suffix}(context.nativeHandle(), nativeHandle(), ((value : Bool) ? 1 : 0)); }'
      : '{ quadrants.Native.ndarray_fill_${suffix}(context.nativeHandle(), nativeHandle(), cast value); }'));

    add("read", [APublic, AInline], fun([
      DTypeBuild.arg("flatIndex", DTypeBuild.intType())
    ], valueType, spec.typeName == "U1"
      ? '{ return cast (quadrants.Native.ndarray_read_${suffix}(context.nativeHandle(), nativeHandle(), flatIndex) != 0); }'
      : '{ return cast quadrants.Native.ndarray_read_${suffix}(context.nativeHandle(), nativeHandle(), flatIndex); }'));

    add("write", [APublic, AInline], fun([
      DTypeBuild.arg("flatIndex", DTypeBuild.intType()),
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), spec.typeName == "U1"
      ? '{ quadrants.Native.ndarray_write_${suffix}(context.nativeHandle(), nativeHandle(), flatIndex, ((value : Bool) ? 1 : 0)); }'
      : '{ quadrants.Native.ndarray_write_${suffix}(context.nativeHandle(), nativeHandle(), flatIndex, cast value); }'));

    add("scalarRead", [APublic, AInline], fun([], valueType, "return read(0)"));

    add("scalarWrite", [APublic, AInline], fun([
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), "{ write(0, value); }"));

    add("kernelRead", [APublic], fun([
      DTypeBuild.arg("flatIndex", DTypeBuild.intType())
    ], valueType, "return read(flatIndex)"));

    add("kernelWrite", [APublic], fun([
      DTypeBuild.arg("flatIndex", DTypeBuild.intType()),
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), "{ write(flatIndex, value); }"));

    add("readAt", [APublic, AInline], fun([
      DTypeBuild.arg("indices", macro : Array<Int>)
    ], valueType, "return read(flatIndex(indices))"));

    add("writeAt", [APublic, AInline], fun([
      DTypeBuild.arg("indices", macro : Array<Int>),
      DTypeBuild.arg("value", valueType)
    ], DTypeBuild.voidType(), "{ write(flatIndex(indices), value); }"));

    add("toArray", [APublic], fun([], arrayValueType,
      '{ var result = new Array<${typePathName}>(); var count = elementCount(); for (i in 0...count) result.push(read(i)); return result; }'));

    add("fromArray", [APublic], fun([
      DTypeBuild.arg("values", arrayValueType)
    ], DTypeBuild.voidType(),
      '{ quadrants.TensorStorage.requireElementCount(shape, values.length); for (i in 0...values.length) write(i, values[i]); }'));

    add("copyFrom", [APublic], fun([
      DTypeBuild.arg("source", self)
    ], DTypeBuild.voidType(),
      '{ quadrants.TensorStorage.requireSameShape(shape, source.shape, "Tensor.copyFrom"); var count = elementCount(); for (i in 0...count) write(i, source.read(i)); }'));

    add("copyTo", [APublic], fun([
      DTypeBuild.arg("target", self)
    ], DTypeBuild.voidType(),
      '{ target.copyFrom(this); }'));

    add("view", [APublic], fun([
      DTypeBuild.arg("flatStart", DTypeBuild.intType()),
      DTypeBuild.arg("length", DTypeBuild.intType())
    ], viewType,
      '{ return new quadrants.BufferView<${typePathName}>(this, flatStart, length, function(index:Int):${typePathName} { return read(index); }, function(index:Int, value:${typePathName}):Void { write(index, value); }); }'));

    Context.defineType({
      pack: DTypeBuild.generatedPack,
      name: className,
      pos: pos,
      meta: [],
      params: [],
      isExtern: false,
      kind: TDClass({pack: ["quadrants"], name: "TensorRuntime"}, [{pack: ["quadrants"], name: "TensorArg", params: [TPType(valueType)]}], false, false, false),
      fields: fields
    });
  }
}
#end
