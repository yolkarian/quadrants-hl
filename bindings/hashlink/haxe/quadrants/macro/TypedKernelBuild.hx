package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

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
    if (sourceArgs.length > 12) {
      Context.error("Quadrants typed kernels currently support up to 12 parameters", functionExpr.pos);
    }
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

    var wrapperType = wrapperComplexType(args, returnType);
    var wrapperPath = wrapperPath(args.length);
    var rawBuildExpr = optionsExpr == null
      ? macro quadrants.Kernel.buildRaw($e{ctxExpr}, $e{fnExpr})
      : macro quadrants.Kernel.buildRaw($e{ctxExpr}, $e{fnExpr}, $e{optionsExpr});

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
      appendStatements.push(macro quadrants.kernel.ArgEncoding.append(__qd_buf, $i{arg.name}));
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
        macro raw.launchOnDynamic(stream, __qd_buf.toArray());
      } else if (useGraph) {
        macro raw.launchGraphDynamic(__qd_buf.toArray());
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
        var __qd_result:$returnType = quadrants.Struct.decodeSchema($e{schemaExpr}, raw.launchRetsDynamic(__qd_buf.toArray()));
        __qd_buf.release();
        return __qd_result;
      };
    }

    return macro {
      var __qd_buf = quadrants.kernel.ArgBuffer.acquire();
      $b{appendStatements};
      var __qd_result:$returnType = cast raw.launchRetDynamic(__qd_buf.toArray());
      __qd_buf.release();
      return __qd_result;
    };
  }

  public static function wrapperComplexType(args:Array<FunctionArg>, returnType:ComplexType):ComplexType {
    var params:Array<TypeParam> = [for (arg in args) TPType(arg.type)];
    params.push(TPType(returnType));
    return TPath({pack: ["quadrants", "kernel"], name: 'QKernel${args.length}', params: params});
  }

  static function wrapperPath(arity:Int):Array<String> {
    return ["quadrants", "kernel", 'QKernel${arity}'];
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
