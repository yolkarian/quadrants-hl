package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;

private typedef FlattenedMember = {
  var flatName:String;
  var path:String;
  var type:ComplexType;
  var accessExpr:Expr;
  var role:String;
}

class FlattenBuild {
  public static function build(ctxExpr:Expr, fnExpr:Expr, ?optionsExpr:Expr):Expr {
    var functionExpr = quadrants.macro.KernelBuilder.decodeMacroExpr(fnExpr);
    var functionDef = switch (functionExpr.expr) {
      case EFunction(_, f): f;
      default: Context.error("quadrants.QD.kernel expects a macro arrow function", functionExpr.pos);
    };
    if (functionDef.expr == null) {
      Context.error("Quadrants flatten kernel function must have a body", functionExpr.pos);
    }

    var sourceArgs = functionDef.args;
    var mapping = new Map<String, String>();
    var transformedArgs = new Array<FunctionArg>();
    var appendStatements = new Array<Expr>();
    var metadataArgs:Array<Dynamic> = [];
    var hasFlatten = false;

    for (arg in sourceArgs) {
      if (arg.type == null) {
        Context.error('Quadrants typed kernel parameter ${arg.name} requires an explicit type annotation', arg.value == null ? functionExpr.pos : arg.value.pos);
      }
      var flattenClass = flattenClassType(arg.type, functionExpr.pos);
      if (flattenClass == null) {
        transformedArgs.push({name: arg.name, opt: false, type: arg.type, value: null});
        appendStatements.push(macro quadrants.kernel.ArgEncoding.append(__qd_buf, $i{arg.name}));
        metadataArgs.push({path: arg.name, role: "runtime", kind: paramKindForComplexType(arg.type, functionExpr.pos), dtype: dtypeForComplexType(arg.type, functionExpr.pos), rank: rankForComplexType(arg.type, functionExpr.pos)});
        continue;
      }
      hasFlatten = true;
      var members = flattenMembers(arg.name, identExpr(arg.name, functionExpr.pos), arg.type, functionExpr.pos, mapping);
      for (member in members) {
        transformedArgs.push({name: member.flatName, opt: false, type: member.type, value: null});
        appendStatements.push(macro quadrants.kernel.ArgEncoding.append(__qd_buf, $e{member.accessExpr}));
        metadataArgs.push({path: member.path, role: member.role, kind: paramKindForComplexType(member.type, functionExpr.pos), dtype: dtypeForComplexType(member.type, functionExpr.pos), rank: rankForComplexType(member.type, functionExpr.pos)});
      }
    }

    if (!hasFlatten) {
      return quadrants.macro.TypedKernelBuild.build(ctxExpr, fnExpr, optionsExpr);
    }

    var rewrittenBody = rewriteFlattenExpression(functionDef.expr, mapping);
    var transformedFunction:Expr = {
      expr: EFunction(FAnonymous, {
        args: transformedArgs,
        ret: functionDef.ret,
        expr: rewrittenBody,
      }),
      pos: functionExpr.pos,
    };

    var returnType = functionDef.ret != null ? functionDef.ret : quadrants.macro.TypedKernelBuild.expectedKernelReturnType(sourceArgs.length, functionExpr.pos);
    if (returnType == null) {
      returnType = quadrants.macro.TypedKernelBuild.voidType();
    }

    var wrapperType = quadrants.macro.TypedKernelBuild.wrapperComplexType([for (arg in sourceArgs) {name: arg.name, opt: false, type: arg.type, value: null}], returnType);
    var kernelName = kernelNameFromOptions(optionsExpr, functionExpr.pos);
    var metadataJson = descriptorMetadataJson(kernelName, metadataArgs);
    var descriptorOptions = mergeOptionsWithMetadata(optionsExpr, metadataJson, functionExpr.pos);
    var rawBuildExpr = macro quadrants.Kernel.buildRaw($e{ctxExpr}, $e{transformedFunction}, $e{descriptorOptions});

    var launchExpr = buildLaunchFunction(sourceArgs, appendStatements, returnType, false, false, functionExpr.pos);
    var launchOnExpr = buildLaunchFunction(sourceArgs, appendStatements, returnType, true, false, functionExpr.pos);
    var launchGraphExpr = buildLaunchFunction(sourceArgs, appendStatements, returnType, false, true, functionExpr.pos);

    var newWrapper:Expr = {
      expr: ENew(quadrants.macro.TypedKernelBuild.wrapperTypePath(sourceArgs.length), [macro raw, launchExpr, launchOnExpr, launchGraphExpr, macro __qd_wrap]),
      pos: functionExpr.pos,
    };

    return macro {
      function __qd_wrap(raw:quadrants.KernelRaw):$wrapperType {
        return $e{newWrapper};
      }
      __qd_wrap($e{rawBuildExpr});
    };
  }

  static function buildLaunchFunction(args:Array<FunctionArg>, appendStatements:Array<Expr>, returnType:ComplexType, useStream:Bool, useGraph:Bool, pos:Position):Expr {
    var closureArgs = new Array<FunctionArg>();
    if (useStream) {
      closureArgs.push({name: "stream", opt: false, type: macro : quadrants.Stream, value: null});
    }
    for (arg in args) {
      closureArgs.push({name: arg.name, opt: false, type: arg.type, value: null});
    }
    var body = quadrants.macro.TypedKernelBuild.buildLaunchBody(returnType, appendStatements, useStream, useGraph, pos);
    return {
      expr: EFunction(FAnonymous, {
        args: closureArgs,
        ret: returnType,
        expr: body,
      }),
      pos: pos,
    };
  }

  static function descriptorMetadataJson(kernelName:String, args:Array<Dynamic>):String {
    var typeIds = new Map<String, Int>();
    var types:Array<Dynamic> = [];
    var schemaArgs:Array<Dynamic> = [];
    var templates:Array<Dynamic> = [];
    var resources:Array<Dynamic> = [];
    var capabilities:Array<String> = [];

    function dtypeName(dtype:Int):String {
      return switch (dtype) {
        case 0: "i8";
        case 1: "i16";
        case 2: "i32";
        case 3: "i64";
        case 4: "u8";
        case 5: "u16";
        case 6: "u32";
        case 7: "u64";
        case 8: "f32";
        case 9: "f64";
        case 10: "u1";
        case 11: "f16";
        default: 'unknown(${dtype})';
      };
    }

    function kindName(kind:Int):String {
      return switch (kind) {
        case 0: "scalar";
        case 1: "tensor";
        case 2: "field";
        default: 'unknown(${kind})';
      };
    }

    function typeKind(kind:Int):String {
      return switch (kind) {
        case 0: "primitive";
        case 1: "tensor_resource";
        case 2: "field_resource";
        default: "primitive";
      };
    }

    function typeIdOf(kind:Int, dtype:Int, rank:Int):Int {
      var key = kind + ":" + dtype + ":" + rank;
      var existing = typeIds.get(key);
      if (existing != null) {
        return existing;
      }
      var id = types.length + 1;
      typeIds.set(key, id);
      types.push({id: id, kind: typeKind(kind), dtype: dtypeName(dtype), rank: rank});
      return id;
    }

    for (index in 0...args.length) {
      var arg = args[index];
      var kind:Int = Reflect.field(arg, "kind");
      var dtype:Int = Reflect.field(arg, "dtype");
      var rank:Int = Reflect.field(arg, "rank");
      var role:String = Reflect.field(arg, "role");
      var path:String = Reflect.field(arg, "path");
      var typeId = typeIdOf(kind, dtype, rank);
      schemaArgs.push({index: index, path: path, role: role, kind: kindName(kind), typeId: typeId});
      if (role == "template") {
        templates.push({path: path, type: dtypeName(dtype), value: "runtime"});
        if (capabilities.indexOf("template_constants") < 0) {
          capabilities.push("template_constants");
        }
      }
      if (kind != 0) {
        resources.push({path: path, kind: kindName(kind), typeId: typeId});
      }
      if (kind == 2 && capabilities.indexOf("field_direct_param") < 0) {
        capabilities.push("field_direct_param");
      }
    }
    return haxe.Json.stringify({
      version: 2,
      kernelName: kernelName,
      types: types,
      args: schemaArgs,
      templates: templates,
      resources: resources,
      capabilities: capabilities,
    });
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
        Context.error("quadrants.QD.kernel options must be an object literal when flatten metadata is required", expr.pos);
    };
  }

  static function paramKindForComplexType(type:ComplexType, pos:Position):Int {
    return switch (Context.followWithAbstracts(Context.resolveType(type, pos))) {
      case TInst(classRef, _):
        var name = classRef.get().name;
        if (name == "Field" || name == "VectorField" || name == "MatrixField" || StringTools.startsWith(name, "Field_")) {
          2;
        } else if (name == "Tensor" || name == "BufferView" || name == "VectorNdarray" || name == "MatrixNdarray" || StringTools.startsWith(name, "Tensor_")) {
          1;
        } else {
          0;
        }
      default:
        0;
    };
  }

  static function rankForComplexType(type:ComplexType, pos:Position):Int {
    return switch (Context.followWithAbstracts(Context.resolveType(type, pos))) {
      case TInst(classRef, _):
        var name = classRef.get().name;
        if (name == "Tensor" || name == "Field" || name == "BufferView" || name == "VectorNdarray" || name == "MatrixNdarray" || name == "VectorField" || name == "MatrixField" || StringTools.startsWith(name, "Tensor_") || StringTools.startsWith(name, "Field_")) {
          1;
        } else {
          0;
        }
      default:
        0;
    };
  }

  static function dtypeForComplexType(type:ComplexType, pos:Position):Int {
    return switch (stripType(type)) {
      case TPath(path):
        var typeName = path.name;
        if ((typeName == "Tensor" || typeName == "Field" || typeName == "BufferView" || typeName == "VectorNdarray" || typeName == "MatrixNdarray" || typeName == "VectorField" || typeName == "MatrixField") && path.params.length > 0) {
          dtypeFromTypeParam(path.params[0], pos);
        } else {
          dtypeNameToId(typeName);
        }
      default:
        2;
    };
  }

  static function stripType(type:ComplexType):ComplexType {
    return switch (type) {
      case TParent(inner): stripType(inner);
      default: type;
    };
  }

  static function dtypeFromTypeParam(param:TypeParam, pos:Position):Int {
    return switch (param) {
      case TPType(inner): dtypeForComplexType(inner, pos);
      default: 2;
    };
  }

  static function dtypeNameToId(name:String):Int {
    return switch (name) {
      case "I8": 0;
      case "I16": 1;
      case "I32": 2;
      case "I64": 3;
      case "U8": 4;
      case "U16": 5;
      case "U32": 6;
      case "U64": 7;
      case "F32": 8;
      case "F64": 9;
      case "U1": 10;
      case "F16": 11;
      default: 2;
    };
  }

  static function isNullLiteral(expr:Expr):Bool {
    return switch (expr.expr) {
      case EConst(CIdent("null")): true;
      default: false;
    };
  }

  static function kernelNameFromOptions(options:Null<Expr>, pos:Position):String {
    if (options == null) {
      return kernelNameFromPosition(pos);
    }
    var expr = strip(options);
    if (isNullLiteral(expr)) {
      return kernelNameFromPosition(pos);
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        for (field in fields) {
          if (field.field == "name" || field.field == "debugName") {
            return stringLiteral(field.expr);
          }
        }
        kernelNameFromPosition(pos);
      default:
        Context.error("quadrants.QD.kernel options must be an object literal", expr.pos);
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

  static function flattenMembers(rootName:String,
      rootExpr:Expr,
      rootType:ComplexType,
      pos:Position,
      mapping:Map<String, String>):Array<FlattenedMember> {
    var result = new Array<FlattenedMember>();
    var classType = flattenClassType(rootType, pos);
    if (classType == null) {
      return result;
    }

    var dataOrientedCtxField = dataOrientedCtxFieldName(classType);
    for (field in classType.fields.get()) {
      switch (field.kind) {
        case FVar(_, _):
        default:
          continue;
      }
      if (field.name == dataOrientedCtxField || StringTools.startsWith(field.name, "__qd_")) {
        continue;
      }
      if (hasMeta(field.meta, ":qdIgnore") || hasMeta(field.meta, "qdIgnore")) {
        continue;
      }
      var fieldType = TypeTools.toComplexType(field.type);
      if (fieldType == null) {
        Context.error('Quadrants flatten field ${field.name} could not be converted to a concrete Haxe type', field.pos);
      }
      var fieldAccess = fieldAccessExpr(rootExpr, field.name, field.pos);
      var fieldPath = rootName + "." + field.name;
      var nestedClass = flattenClassType(fieldType, field.pos);
      if (nestedClass != null) {
        for (member in flattenMembers(fieldPath, fieldAccess, fieldType, field.pos, mapping)) {
          result.push(member);
        }
        continue;
      }
      if (isDynamicType(field.type)) {
        Context.error('Quadrants flatten field ${fieldPath} cannot use Dynamic', field.pos);
      }
      if (isResourceType(field.type)) {
        var flatName = sanitizePath(fieldPath);
        mapping.set(fieldPath, flatName);
        result.push({flatName: flatName, path: fieldPath, type: fieldType, accessExpr: fieldAccess, role: "runtime"});
        continue;
      }
      if (hasMeta(field.meta, ":template") || hasMeta(field.meta, "template") || hasMeta(field.meta, ":param") || hasMeta(field.meta, "param")) {
        var flatName = sanitizePath(fieldPath);
        mapping.set(fieldPath, flatName);
        result.push({flatName: flatName, path: fieldPath, type: fieldType, accessExpr: fieldAccess, role: hasMeta(field.meta, ":template") || hasMeta(field.meta, "template") ? "template" : "runtime"});
        continue;
      }
      Context.error('Quadrants flatten primitive field ${fieldPath} must be marked @:template or @:param', field.pos);
    }
    return result;
  }

  static function flattenClassType(type:ComplexType, pos:Position):Null<ClassType> {
    return switch (Context.followWithAbstracts(Context.resolveType(type, pos))) {
      case TInst(classRef, _):
        var classType = classRef.get();
        if (hasMeta(classType.meta, ":qdFlatten") || hasMeta(classType.meta, "qdFlatten")
          || hasMeta(classType.meta, ":qdDataOriented") || hasMeta(classType.meta, "qdDataOriented")
          || extendsDataOriented(classType)) {
          classType;
        } else {
          null;
        }
      default:
        null;
    };
  }

  static function dataOrientedCtxFieldName(classType:ClassType):Null<String> {
    for (entry in classType.meta.extract(":qdDataOriented")) {
      if (entry.params != null && entry.params.length == 1) {
        return stringLiteral(entry.params[0]);
      }
      return "ctx";
    }
    for (entry in classType.meta.extract("qdDataOriented")) {
      if (entry.params != null && entry.params.length == 1) {
        return stringLiteral(entry.params[0]);
      }
      return "ctx";
    }
    return null;
  }

  static function extendsDataOriented(classType:ClassType):Bool {
    var current = classType.superClass;
    while (current != null) {
      var superClass = current.t.get();
      if (superClass.pack.join(".") == "quadrants.flatten" && superClass.name == "DataOriented") {
        return true;
      }
      current = superClass.superClass;
    }
    return false;
  }

  static function isResourceType(type:Type):Bool {
    var followed = Context.followWithAbstracts(type);
    return switch (followed) {
      case TInst(classRef, _):
        var name = classRef.get().name;
        name == "Tensor"
          || name == "Field"
          || name == "BufferView"
          || name == "VectorNdarray"
          || name == "MatrixNdarray"
          || name == "VectorField"
          || name == "MatrixField"
          || StringTools.startsWith(name, "Tensor_")
          || StringTools.startsWith(name, "Field_");
      default:
        false;
    };
  }

  static function isDynamicType(type:Type):Bool {
    return switch (Context.follow(type)) {
      case TDynamic(_): true;
      default: false;
    };
  }

  static function hasMeta(meta:MetaAccess, name:String):Bool {
    return meta != null && meta.extract(name).length > 0;
  }

  static function stringLiteral(expr:Expr):String {
    return switch (expr.expr) {
      case EConst(CString(value, _)): value;
      default: Context.error("Quadrants flatten metadata expects a string literal", expr.pos);
    };
  }

  static function sanitizePath(path:String):String {
    return "__qd_" + path.split(".").join("_");
  }

  static function identExpr(name:String, pos:Position):Expr {
    return {expr: EConst(CIdent(name)), pos: pos};
  }

  static function fieldAccessExpr(base:Expr, field:String, pos:Position):Expr {
    return {expr: EField(base, field), pos: pos};
  }

  static function rewriteFlattenExpression(expr:Expr, mapping:Map<String, String>):Expr {
    var roots = new Map<String, Bool>();
    for (path in mapping.keys()) {
      var root = rootName(path);
      if (root != null) {
        roots.set(root, true);
      }
    }
    return rewriteFlattenExpr(expr, mapping, roots, new Map<String, Bool>());
  }

  static function rewriteFlattenExpr(expr:Expr,
      mapping:Map<String, String>,
      roots:Map<String, Bool>,
      shadowed:Map<String, Bool>):Expr {
    if (expr == null) {
      return null;
    }

    var path = fieldPath(expr);
    if (path != null) {
      var root = rootName(path);
      if (root != null && !shadowed.exists(root)) {
        var flatName = mapping.get(path);
        if (flatName != null) {
          return identExpr(flatName, expr.pos);
        }
      }
    }

    return switch (expr.expr) {
      case EBlock(expressions):
        var localShadowed = cloneScope(shadowed);
        var rewritten = new Array<Expr>();
        for (entry in expressions) {
          var next = rewriteFlattenExpr(entry, mapping, roots, localShadowed);
          rewritten.push(next);
          shadowDeclaredNames(localShadowed, roots, next);
        }
        {expr: EBlock(rewritten), pos: expr.pos};
      case EVars(vars):
        {
          expr: EVars([
            for (variable in vars)
              {
                name: variable.name,
                type: variable.type,
                expr: variable.expr == null ? null : rewriteFlattenExpr(variable.expr, mapping, roots, shadowed),
                isFinal: variable.isFinal,
                meta: variable.meta
              }
          ]),
          pos: expr.pos,
        };
      case EFor(iterator, body):
        var localShadowed = cloneScope(shadowed);
        shadowForBindings(localShadowed, roots, iterator);
        {expr: EFor(rewriteFlattenExpr(iterator, mapping, roots, shadowed), rewriteFlattenExpr(body, mapping, roots, localShadowed)), pos: expr.pos};
      case EFunction(kind, fun):
        var localShadowed = cloneScope(shadowed);
        switch (kind) {
          case FNamed(name, _):
            shadowName(localShadowed, roots, name);
          default:
        }
        for (arg in fun.args) {
          shadowName(localShadowed, roots, arg.name);
        }
        {
          expr: EFunction(kind, {
            args: fun.args,
            ret: fun.ret,
            expr: fun.expr == null ? null : rewriteFlattenExpr(fun.expr, mapping, roots, localShadowed),
            params: fun.params,
          }),
          pos: expr.pos,
        };
      case ETry(body, catches):
        {
          expr: ETry(rewriteFlattenExpr(body, mapping, roots, shadowed), [
            for (caught in catches)
              {
                var catchShadowed = cloneScope(shadowed);
                shadowName(catchShadowed, roots, caught.name);
                {
                  name: caught.name,
                  type: caught.type,
                  expr: rewriteFlattenExpr(caught.expr, mapping, roots, catchShadowed)
                };
              }
          ]),
          pos: expr.pos,
        };
      default:
        ExprTools.map(expr, function(next) return rewriteFlattenExpr(next, mapping, roots, shadowed));
    };
  }

  static function shadowDeclaredNames(scope:Map<String, Bool>, roots:Map<String, Bool>, expr:Expr):Void {
    switch (expr.expr) {
      case EVars(vars):
        for (variable in vars) {
          shadowName(scope, roots, variable.name);
        }
      case EFunction(FNamed(name, _), _):
        shadowName(scope, roots, name);
      default:
    }
  }

  static function shadowForBindings(scope:Map<String, Bool>, roots:Map<String, Bool>, iterator:Expr):Void {
    switch (iterator.expr) {
      case EBinop(OpIn, lhs, _):
        switch (lhs.expr) {
          case EConst(CIdent(name)):
            shadowName(scope, roots, name);
          default:
        }
      default:
    }
  }

  static function shadowName(scope:Map<String, Bool>, roots:Map<String, Bool>, name:String):Void {
    if (roots.exists(name)) {
      scope.set(name, true);
    }
  }

  static function cloneScope(scope:Map<String, Bool>):Map<String, Bool> {
    var copy = new Map<String, Bool>();
    for (name in scope.keys()) {
      copy.set(name, true);
    }
    return copy;
  }

  static function fieldPath(expr:Expr):Null<String> {
    var current = strip(expr);
    return switch (current.expr) {
      case EConst(CIdent(name)):
        name;
      case EField(base, field):
        var basePath = fieldPath(base);
        basePath == null ? null : basePath + "." + field;
      default:
        null;
    };
  }

  static function rootName(path:String):Null<String> {
    var dot = path.indexOf(".");
    return dot < 0 ? path : path.substr(0, dot);
  }

  static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _): strip(inner);
      default: expression;
    };
  }
}
#end
