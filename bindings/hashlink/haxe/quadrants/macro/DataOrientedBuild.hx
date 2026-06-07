package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type.ClassType;

class DataOrientedBuild {
  public static function build():Array<Field> {
    var fields = Context.getBuildFields();
    var localClass = Context.getLocalClass();
    if (localClass == null) {
      return fields;
    }
    var classType = localClass.get();
    var ctxField = ctxFieldName(classType);
    if (!hasInstanceField(fields, ctxField)) {
      Context.error('Quadrants @:qdDataOriented class requires a ctx field named ${ctxField}', Context.currentPos());
    }

    var selfType:ComplexType = TPath({pack: classType.pack, name: classType.name});
    var instanceFieldNames = [for (field in fields) if (isInstanceDataField(field)) field.name];
    var generated:Array<Field> = [];

    for (field in fields) {
      if (!fieldHasMeta(field.meta, ":kernel") && !fieldHasMeta(field.meta, "kernel")) {
        generated.push(field);
        continue;
      }
      var fun = switch (field.kind) {
        case FFun(fn): fn;
        default: Context.error('Quadrants @:kernel member ${field.name} must be an instance method', field.pos);
      };
      for (arg in fun.args) {
        if (arg.type == null) {
          Context.error('Quadrants @:kernel method parameter ${arg.name} requires an explicit type annotation', field.pos);
        }
      }
      var returnType = fun.ret == null ? quadrants.macro.TypedKernelBuild.voidType() : fun.ret;
      var cacheName = '__qd_' + field.name;
      generated.push(cacheField(cacheName, selfType, fun.args, returnType, field.pos));
      generated.push(rewriteKernelMethod(classType.name, ctxField, cacheName, instanceFieldNames, selfType, field, fun, returnType));
    }
    return generated;
  }

  static function rewriteKernelMethod(className:String,
      ctxField:String,
      cacheName:String,
      instanceFieldNames:Array<String>,
      selfType:ComplexType,
      field:Field,
      fun:Function,
      returnType:ComplexType):Field {
    var rewrittenExpr = rewriteMemberIdentifiers(fun.expr == null ? {expr: EBlock([]), pos: field.pos} : fun.expr,
      [for (name in instanceFieldNames) if (name != ctxField && name != cacheName) name],
      [for (arg in fun.args) arg.name]);
    var originalStatements = switch (rewrittenExpr.expr) {
      case EBlock(expressions): expressions;
      default: [rewrittenExpr];
    };
    var kernelBody:Expr = {expr: EBlock(originalStatements), pos: field.pos};
    var kernelFnExpr:Expr = {
      expr: EFunction(FAnonymous, {
        args: [{name: "self", opt: false, type: selfType, value: null}].concat([
          for (arg in fun.args)
            {name: arg.name, opt: false, type: arg.type, value: null}
        ]),
        ret: fun.ret,
        expr: kernelBody,
      }),
      pos: field.pos,
    };

    var cacheFieldExpr = memberExpr(macro this, cacheName, field.pos);
    var ctxExpr = memberExpr(macro this, ctxField, field.pos);
    var methodKernelName = className + "." + field.name;
    var initExpr = macro $e{cacheFieldExpr} = quadrants.QD.kernel($e{ctxExpr}, $e{kernelFnExpr}, {name: $v{methodKernelName}});
    var launchArgs = [for (arg in fun.args) identExpr(arg.name, field.pos)];
    var launchExpr:Expr = {
      expr: ECall(memberExpr(cacheFieldExpr, "launch", field.pos), [macro this].concat(launchArgs)),
      pos: field.pos,
    };
    var methodBody = quadrants.macro.TypedKernelBuild.isVoidType(returnType, field.pos)
      ? macro {
          if ($e{cacheFieldExpr} == null) {
            $e{initExpr};
          }
          $e{launchExpr};
        }
      : macro {
          if ($e{cacheFieldExpr} == null) {
            $e{initExpr};
          }
          return $e{launchExpr};
        };

    return {
      name: field.name,
      access: field.access,
      kind: FFun({
        args: fun.args,
        ret: fun.ret,
        expr: methodBody,
        params: fun.params,
      }),
      pos: field.pos,
      meta: field.meta,
      doc: field.doc,
    };
  }

  static function cacheField(name:String, selfType:ComplexType, args:Array<FunctionArg>, returnType:ComplexType, pos:Position):Field {
    var typeParams:Array<TypeParam> = [TPType(selfType)];
    for (arg in args) {
      typeParams.push(TPType(arg.type));
    }
    typeParams.push(TPType(returnType));
    var cacheType:ComplexType = TPath({pack: ["quadrants", "kernel"], name: 'QKernel${args.length + 1}', params: typeParams});
    return {
      name: name,
      access: [APrivate],
      kind: FVar(cacheType, macro null),
      pos: pos,
      meta: [],
    };
  }

  static function ctxFieldName(classType:ClassType):String {
    for (entry in classType.meta.extract(":qdDataOriented")) {
      if (entry.params != null && entry.params.length == 1) {
        return stringLiteral(entry.params[0]);
      }
    }
    for (entry in classType.meta.extract("qdDataOriented")) {
      if (entry.params != null && entry.params.length == 1) {
        return stringLiteral(entry.params[0]);
      }
    }
    return "ctx";
  }

  static function stringLiteral(expr:Expr):String {
    return switch (expr.expr) {
      case EConst(CString(value, _)): value;
      default: Context.error("Quadrants @:qdDataOriented ctx field must be a string literal", expr.pos);
    };
  }

  static function isInstanceDataField(field:Field):Bool {
    if (field.access != null) {
      for (access in field.access) {
        if (access == AStatic) {
          return false;
        }
      }
    }
    return switch (field.kind) {
      case FVar(_, _) | FProp(_, _, _, _): true;
      default: false;
    };
  }

  static function hasInstanceField(fields:Array<Field>, name:String):Bool {
    for (field in fields) {
      if (field.name == name && isInstanceDataField(field)) {
        return true;
      }
    }
    return false;
  }

  static function fieldHasMeta(meta:Metadata, name:String):Bool {
    if (meta == null) {
      return false;
    }
    for (entry in meta) {
      if (entry.name == name) {
        return true;
      }
    }
    return false;
  }

  static function rewriteMemberIdentifiers(expr:Expr, memberNames:Array<String>, argNames:Array<String>):Expr {
    var members = new Map<String, Bool>();
    for (name in memberNames) {
      members.set(name, true);
    }
    var initialScope = new Map<String, Bool>();
    initialScope.set("self", true);
    for (name in argNames) {
      initialScope.set(name, true);
    }
    return rewriteExpr(expr, members, initialScope);
  }

  static function rewriteExpr(expr:Expr, members:Map<String, Bool>, scope:Map<String, Bool>):Expr {
    if (expr == null) {
      return null;
    }
    return switch (expr.expr) {
      case EConst(CIdent(name)) if (!scope.exists(name) && members.exists(name)):
        memberExpr(identExpr("self", expr.pos), name, expr.pos);
      case EBlock(expressions):
        var localScope = cloneScope(scope);
        var rewritten = new Array<Expr>();
        for (entry in expressions) {
          var next = rewriteExpr(entry, members, localScope);
          rewritten.push(next);
          switch (next.expr) {
            case EVars(vars):
              for (variable in vars) {
                localScope.set(variable.name, true);
              }
            default:
          }
        }
        {expr: EBlock(rewritten), pos: expr.pos};
      case EVars(vars):
        {
          expr: EVars([
            for (variable in vars)
              {
                name: variable.name,
                type: variable.type,
                expr: variable.expr == null ? null : rewriteExpr(variable.expr, members, scope)
              }
          ]),
          pos: expr.pos,
        };
      case EFor(iterator, body):
        var localScope = cloneScope(scope);
        switch (iterator.expr) {
          case EBinop(OpIn, lhs, _):
            switch (lhs.expr) {
              case EConst(CIdent(loopName)):
                localScope.set(loopName, true);
              default:
            }
          default:
        }
        {expr: EFor(rewriteExpr(iterator, members, scope), rewriteExpr(body, members, localScope)), pos: expr.pos};
      default:
        ExprTools.map(expr, function(next) return rewriteExpr(next, members, scope));
    };
  }

  static function cloneScope(scope:Map<String, Bool>):Map<String, Bool> {
    var copy = new Map<String, Bool>();
    for (name in scope.keys()) {
      copy.set(name, true);
    }
    return copy;
  }

  static function identExpr(name:String, pos:Position):Expr {
    return {expr: EConst(CIdent(name)), pos: pos};
  }

  static function memberExpr(base:Expr, field:String, pos:Position):Expr {
    return {expr: EField(base, field), pos: pos};
  }
}
#end
