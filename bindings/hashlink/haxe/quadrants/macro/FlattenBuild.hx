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
    var hasFlatten = false;

    for (arg in sourceArgs) {
      if (arg.type == null) {
        Context.error('Quadrants typed kernel parameter ${arg.name} requires an explicit type annotation', arg.value == null ? functionExpr.pos : arg.value.pos);
      }
      var flattenClass = flattenClassType(arg.type, functionExpr.pos);
      if (flattenClass == null) {
        transformedArgs.push({name: arg.name, opt: false, type: arg.type, value: null});
        appendStatements.push(macro quadrants.kernel.ArgEncoding.append(__qd_buf, $i{arg.name}));
        continue;
      }
      hasFlatten = true;
      var members = flattenMembers(arg.name, identExpr(arg.name, functionExpr.pos), arg.type, functionExpr.pos, mapping);
      for (member in members) {
        transformedArgs.push({name: member.flatName, opt: false, type: member.type, value: null});
        appendStatements.push(macro quadrants.kernel.ArgEncoding.append(__qd_buf, $e{member.accessExpr}));
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
    var rawBuildExpr = optionsExpr == null
      ? macro quadrants.Kernel.buildRaw($e{ctxExpr}, $e{transformedFunction})
      : macro quadrants.Kernel.buildRaw($e{ctxExpr}, $e{transformedFunction}, $e{optionsExpr});

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
        result.push({flatName: flatName, path: fieldPath, type: fieldType, accessExpr: fieldAccess});
        continue;
      }
      if (hasMeta(field.meta, ":template") || hasMeta(field.meta, "template") || hasMeta(field.meta, ":param") || hasMeta(field.meta, "param")) {
        var flatName = sanitizePath(fieldPath);
        mapping.set(fieldPath, flatName);
        result.push({flatName: flatName, path: fieldPath, type: fieldType, accessExpr: fieldAccess});
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
    function rewrite(current:Expr):Expr {
      var path = fieldPath(current);
      if (path != null) {
        var flatName = mapping.get(path);
        if (flatName != null) {
          return identExpr(flatName, current.pos);
        }
      }
      return ExprTools.map(current, rewrite);
    }
    return rewrite(expr);
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

  static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _): strip(inner);
      default: expression;
    };
  }
}
#end
