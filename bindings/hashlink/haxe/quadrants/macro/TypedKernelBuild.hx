package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;
import quadrants.macro.DescriptorMetadata.QdhlParamMeta;

class TypedKernelBuild {
  public static function build(ctxExpr:Expr, fnExpr:Expr, ?optionsExpr:Expr):Expr {
    var functionExpr = quadrants.macro.KernelBuilder.decodeMacroExpr(fnExpr);
    var functionDef = switch (functionExpr.expr) {
      case EFunction(_, f): f;
      default: Context.error("quadrants.QD.kernel expects a macro arrow function", functionExpr.pos);
    };
    if (functionDef.expr == null) {
      Context.error("Quadrants typed kernel function must have a body", functionExpr.pos);
    }

    var sourceArgs = functionDef.args;
    for (arg in sourceArgs) {
      if (arg.type == null) {
        Context.error('Quadrants typed kernel parameter ${arg.name} requires an explicit type annotation', arg.value == null ? functionExpr.pos : arg.value.pos);
      }
    }

    var args = [for (arg in sourceArgs) {name: arg.name, opt: false, type: arg.type, value: null}];
    var returnType = functionDef.ret != null ? functionDef.ret : expectedKernelReturnType(args.length, functionExpr.pos);
    if (returnType == null) {
      returnType = voidType();
    }
    QKernelTypeBuilder.ensure(args.length, functionExpr.pos);

    var wrapperType = wrapperComplexType(args, returnType);
    var metadataArgs = [for (arg in sourceArgs) metadataArg(arg, functionExpr.pos)];
    var descriptorOptions = mergeOptionsWithMetadata(optionsExpr,
      quadrants.macro.DescriptorWriter.metadata(kernelNameFromOptions(optionsExpr, functionExpr.pos), metadataArgs, [], [], []),
      functionExpr.pos);
    var rawBuildExpr = macro quadrants.Kernel.buildRaw($e{ctxExpr}, $e{fnExpr}, $e{descriptorOptions});

    var launchExpr = buildLaunchFunction(args, returnType, false, false, functionExpr.pos);
    var launchOnExpr = buildLaunchFunction(args, returnType, true, false, functionExpr.pos);
    var launchGraphExpr = buildLaunchFunction(args, returnType, false, true, functionExpr.pos);

    var newWrapper:Expr = {
      expr: ENew(wrapperTypePath(args.length), [macro raw, launchExpr, launchOnExpr, launchGraphExpr, macro __qd_wrap]),
      pos: functionExpr.pos,
    };

    return macro {
      function __qd_wrap(raw:quadrants.KernelRaw):$wrapperType {
        return $e{newWrapper};
      }
      __qd_wrap($e{rawBuildExpr});
    };
  }

  static function buildLaunchFunction(args:Array<FunctionArg>, returnType:ComplexType, useStream:Bool, useGraph:Bool, pos:Position):Expr {
    var closureArgs = new Array<FunctionArg>();
    if (useStream) {
      closureArgs.push({name: "stream", opt: false, type: macro : quadrants.Stream, value: null});
    }
    for (arg in args) {
      closureArgs.push({name: arg.name, opt: false, type: arg.type, value: null});
    }

    var appendStatements:Array<Expr> = [];
    for (arg in args) {
      appendStatements.push(appendStatementForExpr({expr: EConst(CIdent(arg.name)), pos: pos}, arg.type, pos));
    }

    var body = buildLaunchBody(returnType, appendStatements, useStream, useGraph, pos);
    return {
      expr: EFunction(FAnonymous, {
        args: closureArgs,
        ret: returnType,
        expr: body,
      }),
      pos: pos,
    };
  }

  public static function buildLaunchBody(returnType:ComplexType,
      appendStatements:Array<Expr>,
      useStream:Bool,
      useGraph:Bool,
      pos:Position):Expr {
    var isVoid = isVoidType(returnType, pos);
    var schemaExpr = isVoid ? null : schemaExprForComplexType(returnType, pos);
    if (isVoid) {
      var execExpr = if (useStream) {
        macro raw.launchOnBuffer(stream, __qd_buf);
      } else if (useGraph) {
        macro raw.launchGraphBuffer(__qd_buf);
      } else {
        macro raw.launchBuffer(__qd_buf);
      };
      return macro {
        var __qd_buf = quadrants.kernel.ArgBuffer.acquire();
        $b{appendStatements};
        $e{execExpr};
        __qd_buf.release();
      };
    }

    if (useStream) {
      return macro {
        var __qd_buf = quadrants.kernel.ArgBuffer.acquire();
        $b{appendStatements};
        var __qd_result:$returnType = cast quadrants.kernel.ReturnDecoder.unsupportedReturnOnStream(raw.kernelName());
        __qd_buf.release();
        return __qd_result;
      };
    }
    if (useGraph) {
      return macro {
        var __qd_buf = quadrants.kernel.ArgBuffer.acquire();
        $b{appendStatements};
        var __qd_result:$returnType = cast quadrants.kernel.ReturnDecoder.unsupportedReturnOnGraph(raw.kernelName());
        __qd_buf.release();
        return __qd_result;
      };
    }
    if (schemaExpr != null) {
      return macro {
        var __qd_buf = quadrants.kernel.ArgBuffer.acquire();
        $b{appendStatements};
        var __qd_result:$returnType = quadrants.Struct.decodeSchema($e{schemaExpr}, raw.launchRetsBuffer(__qd_buf));
        __qd_buf.release();
        return __qd_result;
      };
    }

    return macro {
      var __qd_buf = quadrants.kernel.ArgBuffer.acquire();
      $b{appendStatements};
      var __qd_result:$returnType = cast raw.launchRetBuffer(__qd_buf);
      __qd_buf.release();
      return __qd_result;
    };
  }

  public static function appendStatementForExpr(valueExpr:Expr, type:ComplexType, pos:Position):Expr {
    var method = writerMethodForComplexType(type, pos);
    return writerCall(method, valueExpr, pos);
  }

  static function writerCall(method:String, valueExpr:Expr, pos:Position):Expr {
    var quadrantsPath:Expr = {expr: EConst(CIdent("quadrants")), pos: pos};
    var internalPath:Expr = {expr: EField(quadrantsPath, "internal"), pos: pos};
    var writerPath:Expr = {expr: EField(internalPath, "ArgWriter"), pos: pos};
    var methodPath:Expr = {expr: EField(writerPath, method), pos: pos};
    return {expr: ECall(methodPath, [{expr: EConst(CIdent("__qd_buf")), pos: pos}, valueExpr]), pos: pos};
  }

  static function writerMethodForComplexType(type:ComplexType, pos:Position):String {
    if (isSpecComplexType(type)) {
      return "spec";
    }
    if (isStructTensorComplexType(type)) {
      return "structTensor";
    }
    if (isStructFieldComplexType(type)) {
      return "structField";
    }
    if (isMeshRelationComplexType(type)) {
      return "meshRelation";
    }
    if (isMeshAttributeComplexType(type)) {
      return "meshAttribute";
    }
    if (isQuantizedF32TensorComplexType(type)) {
      return "quantizedF32Tensor";
    }
    var kind = paramKindForComplexType(type, pos);
    var suffix = dtypeSuffix(dtypeForComplexType(type, pos));
    return switch (kind) {
      case 1:
        isBufferViewComplexType(type) ? 'bufferView${suffix}' : 'tensor${suffix}';
      case 2:
        'field${suffix}';
      default:
        'scalar${suffix}';
    };
  }

  static function metadataArg(arg:FunctionArg, pos:Position):QdhlParamMeta {
    var role = isSpecComplexType(arg.type) ? "spec" : "runtime";
    return {
      path: arg.name,
      role: role,
      kind: paramKindForComplexType(arg.type, pos),
      dtype: dtypeForComplexType(arg.type, pos),
      rank: rankForComplexType(arg.type, pos),
    };
  }

  static function mergeOptionsWithMetadata(optionsExpr:Null<Expr>, metadataJson:String, pos:Position):Expr {
    var metadataField:ObjectField = {field: "__qdhlMeta", expr: macro $v{metadataJson}};
    if (optionsExpr == null) {
      return {expr: EObjectDecl([metadataField]), pos: pos};
    }
    var expr = strip(optionsExpr);
    if (isNullLiteral(expr)) {
      return {expr: EObjectDecl([metadataField]), pos: pos};
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        {expr: EObjectDecl(fields.concat([metadataField])), pos: pos};
      default:
        Context.error("quadrants.Kernel.build options must be an object literal when descriptor metadata is generated", expr.pos);
    };
  }

  static function kernelNameFromOptions(options:Null<Expr>, pos:Position):String {
    if (options == null || isNullLiteral(strip(options))) {
      return kernelNameFromPosition(pos);
    }
    return switch (strip(options).expr) {
      case EObjectDecl(fields):
        for (field in fields) {
          if (field.field == "name" || field.field == "debugName") {
            return stringLiteral(field.expr);
          }
        }
        kernelNameFromPosition(pos);
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", strip(options).pos);
    };
  }

  static function kernelNameFromPosition(pos:Position):String {
    var info = Context.getPosInfos(pos);
    var file = info.file;
    var slash = file.lastIndexOf("/");
    if (slash >= 0) {
      file = file.substr(slash + 1);
    }
    file = file.split(".").join("_");
    return 'haxe_kernel_${file}_${info.min}_${info.max}';
  }

  static function stringLiteral(expr:Expr):String {
    return switch (expr.expr) {
      case EConst(CString(value, _)): value;
      default: Context.error("Quadrants kernel metadata expects a string literal", expr.pos);
    };
  }

  static function isNullLiteral(expr:Expr):Bool {
    return switch (expr.expr) {
      case EConst(CIdent("null")): true;
      default: false;
    };
  }

  static function paramKindForComplexType(type:ComplexType, pos:Position):Int {
    return switch (stripType(type)) {
      case TPath(path) if (isMeshRelationPath(path)): 3;
      case TPath(path) if (isMeshAttributePath(path)): 4;
      case TPath(path) if (isFieldPath(path) || isStructFieldPath(path)): 2;
      case TPath(path) if (isTensorPath(path) || isBufferViewPath(path) || isStructTensorPath(path) || isQuantizedF32TensorPath(path)): 1;
      default: 0;
    };
  }

  static function rankForComplexType(type:ComplexType, pos:Position):Int {
    return paramKindForComplexType(type, pos) == 0 ? 0 : 1;
  }

  static function dtypeForComplexType(type:ComplexType, pos:Position):Int {
    return switch (stripType(type)) {
      case TPath(path) if (isStructTensorPath(path) || isStructFieldPath(path) || isMeshRelationPath(path) || isQuantizedF32TensorPath(path)):
        2;
      case TPath(path) if (isMeshAttributePath(path)):
        if (path.params == null || path.params.length != 2) Context.error("Quadrants MeshAttribute<Element, Value> requires two type parameters", pos);
        switch (path.params[1]) {
          case TPType(inner): dtypeForComplexType(inner, pos);
          default: Context.error("Quadrants MeshAttribute value type parameter must be a type", pos);
        }
      case TPath(path) if (isSpecPath(path)):
        if (path.params == null || path.params.length != 1) {
          Context.error("Quadrants Spec<T> requires exactly one type parameter", pos);
        }
        switch (path.params[0]) {
          case TPType(inner): dtypeForComplexType(inner, pos);
          default: Context.error("Quadrants Spec<T> type parameter must be a type", pos);
        }
      case TPath(path) if (generatedResourceDType(path) != null):
        generatedResourceDType(path);
      case TPath(path) if ((isTensorPath(path) || isFieldPath(path) || isBufferViewPath(path)) && path.params.length > 0):
        switch (path.params[0]) {
          case TPType(inner): dtypeForComplexType(inner, pos);
          default: Context.error("Quadrants resource type parameter must be a type", pos);
        }
      case TPath(path):
        dtypeNameToId(typePathName(path), pos);
      default:
        Context.error("Unsupported Quadrants typed kernel argument type", pos);
    };
  }

  static function dtypeSuffix(dtype:Int):String {
    return switch (dtype) {
      case 0: "I8";
      case 1: "I16";
      case 2: "I32";
      case 3: "I64";
      case 4: "U8";
      case 5: "U16";
      case 6: "U32";
      case 7: "U64";
      case 8: "F32";
      case 9: "F64";
      case 10: "U1";
      case 11: "F16";
      default: "I32";
    };
  }

  static function dtypeNameToId(fullName:String, pos:Position):Int {
    return switch (fullName) {
      case "Int" | "StdTypes.Int" | "I32" | "quadrants.I32" | "quadrants.Types.I32" | "Types.I32": 2;
      case "Bool" | "StdTypes.Bool" | "U1" | "quadrants.U1" | "quadrants.Types.U1" | "Types.U1": 10;
      case "UInt" | "StdTypes.UInt" | "U32" | "quadrants.U32" | "quadrants.Types.U32" | "Types.U32": 6;
      case "haxe.Int64" | "Int64" | "I64" | "quadrants.I64" | "quadrants.Types.I64" | "Types.I64": 3;
      case "Float" | "StdTypes.Float" | "F64" | "quadrants.F64" | "quadrants.Types.F64" | "Types.F64": 9;
      case "hl.F32" | "F32" | "quadrants.F32" | "quadrants.Types.F32" | "Types.F32": 8;
      case "F16" | "quadrants.F16" | "quadrants.Types.F16" | "Types.F16": 11;
      case "I8" | "quadrants.I8" | "quadrants.Types.I8" | "Types.I8": 0;
      case "I16" | "quadrants.I16" | "quadrants.Types.I16" | "Types.I16": 1;
      case "U8" | "quadrants.U8" | "quadrants.Types.U8" | "Types.U8": 4;
      case "U16" | "quadrants.U16" | "quadrants.Types.U16" | "Types.U16": 5;
      case "U64" | "quadrants.U64" | "quadrants.Types.U64" | "Types.U64": 7;
      default: Context.error('Unsupported Quadrants typed kernel dtype ${fullName}', pos);
    };
  }

  static function generatedResourceDType(path:TypePath):Null<Int> {
    var fullName = typePathName(path);
    var tensorPrefix = "quadrants._generated.Tensor_";
    var fieldPrefix = "quadrants._generated.Field_";
    if (StringTools.startsWith(fullName, tensorPrefix)) {
      return dtypeNameToId(fullName.substr(tensorPrefix.length), Context.currentPos());
    }
    if (StringTools.startsWith(fullName, fieldPrefix)) {
      return dtypeNameToId(fullName.substr(fieldPrefix.length), Context.currentPos());
    }
    return null;
  }

  static function isTensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Tensor" || fullName == "quadrants.Tensor" || StringTools.startsWith(fullName, "quadrants._generated.Tensor_");
  }

  static function isFieldPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Field" || fullName == "quadrants.Field" || fullName == "FieldArg" || fullName == "quadrants.FieldArg" || StringTools.startsWith(fullName, "quadrants._generated.Field_");
  }

  static function isBufferViewPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "BufferView" || fullName == "quadrants.BufferView";
  }

  static function isStructTensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "StructTensor" || fullName == "quadrants.StructTensor";
  }

  static function isStructFieldPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "StructField" || fullName == "quadrants.StructField";
  }

  static function isMeshRelationPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "MeshRelation" || fullName == "quadrants.mesh.MeshRelation";
  }

  static function isMeshAttributePath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "MeshAttribute" || fullName == "quadrants.mesh.MeshAttribute";
  }

  static function isQuantizedF32TensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "QuantizedF32Tensor" || fullName == "quadrants.quant.QuantizedF32Tensor";
  }

  static function isStructTensorComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isStructTensorPath(path);
      default: false;
    };
  }

  static function isStructFieldComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isStructFieldPath(path);
      default: false;
    };
  }

  static function isMeshRelationComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isMeshRelationPath(path);
      default: false;
    };
  }

  static function isMeshAttributeComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isMeshAttributePath(path);
      default: false;
    };
  }

  static function isQuantizedF32TensorComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isQuantizedF32TensorPath(path);
      default: false;
    };
  }

  static function isBufferViewComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isBufferViewPath(path);
      default: false;
    };
  }

  static function isSpecComplexType(type:ComplexType):Bool {
    return switch (stripType(type)) {
      case TPath(path): isSpecPath(path);
      default: false;
    };
  }

  static function isSpecPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Spec" || fullName == "quadrants.Spec";
  }

  static function stripType(type:ComplexType):ComplexType {
    return switch (type) {
      case TParent(inner): stripType(inner);
      default: type;
    };
  }

  static function typePathName(path:TypePath):String {
    return (path.pack.length == 0 ? "" : path.pack.join(".") + ".") + path.name + (path.sub == null ? "" : "." + path.sub);
  }

  public static function wrapperComplexType(args:Array<FunctionArg>, returnType:ComplexType):ComplexType {
    var params:Array<TypeParam> = [for (arg in args) TPType(arg.type)];
    params.push(TPType(returnType));
    return TPath({pack: ["quadrants", "kernel"], name: 'QKernel${args.length}', params: params});
  }


  public static function wrapperTypePath(arity:Int):TypePath {
    return {pack: ["quadrants", "kernel"], name: 'QKernel${arity}'};
  }

  public static function expectedKernelReturnType(arity:Int, pos:Position):Null<ComplexType> {
    var expected = Context.getExpectedType();
    if (expected == null) {
      return null;
    }
    return switch (Context.followWithAbstracts(expected)) {
      case TInst(classRef, params):
        var classType = classRef.get();
        if (classType.pack.join(".") == "quadrants.kernel" && classType.name == 'QKernel${arity}' && params.length == arity + 1) {
          TypeTools.toComplexType(params[params.length - 1]);
        } else {
          null;
        }
      default:
        null;
    };
  }

  static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _): strip(inner);
      default: expression;
    };
  }

  public static function voidType():ComplexType {
    return TPath({pack: [], name: "Void"});
  }

  public static function isVoidType(type:ComplexType, pos:Position):Bool {
    return switch (Context.followWithAbstracts(Context.resolveType(type, pos))) {
      case TAbstract(abstractRef, _):
        abstractRef.get().name == "Void";
      default:
        false;
    };
  }

  static function schemaExprForComplexType(type:ComplexType, pos:Position):Null<Expr> {
    return schemaExprForType(Context.resolveType(type, pos), pos);
  }

  static function schemaExprForType(type:Type, pos:Position):Null<Expr> {
    var followed = followedType(type);
    return switch (followed) {
      case TAnonymous(anonRef):
        {
          expr: EObjectDecl([
            for (field in anonRef.get().fields)
              {
                field: field.name,
                expr: schemaFieldExpr(field.type, pos),
              }
          ]),
          pos: pos,
        };
      default:
        null;
    };
  }

  static function schemaFieldExpr(type:Type, pos:Position):Expr {
    var nested = schemaExprForType(type, pos);
    return nested == null ? macro 0 : nested;
  }

  static function followedType(type:Type):Type {
    return Context.followWithAbstracts(Context.follow(type));
  }
}
#end
