package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class StructMacro {
  public static function decode(typeExpr:Expr, valuesExpr:Expr):Expr {
    var resolved = resolveStructType(typeExpr);
    var state = {index: 0};
    return buildStructExpr(resolved, valuesExpr, state, typeExpr.pos);
  }
  public static function decodeSchema(schemaExpr:Expr, valuesExpr:Expr):Expr {
    var state = {index: 0};
    return buildSchemaExpr(strip(schemaExpr), valuesExpr, state);
  }


  static function resolveStructType(typeExpr:Expr):Type {
    var complex = decodeQuotedComplexType(strip(typeExpr));
    return Context.followWithAbstracts(Context.resolveType(complex, typeExpr.pos));
  }

  static function buildStructExpr(type:Type, valuesExpr:Expr, state:{var index:Int;}, pos:Position):Expr {
    var followed = Context.followWithAbstracts(type);
    return switch (followed) {
      case TAnonymous(anonRef):
        var fields = anonRef.get().fields;
        var exprFields = new Array<ObjectField>();
        for (field in fields) {
          exprFields.push({field: field.name, expr: buildFieldExpr(field.type, valuesExpr, state, pos)});
        }
        {expr: EObjectDecl(exprFields), pos: pos};
      default:
        Context.error("Quadrants Struct.decode expects a typedef or anonymous-structure type", pos);
    };
  }

  static function buildFieldExpr(type:Type, valuesExpr:Expr, state:{var index:Int;}, pos:Position):Expr {
    var followed = Context.followWithAbstracts(type);
    return switch (followed) {
      case TAnonymous(_):
        buildStructExpr(followed, valuesExpr, state, pos);
      default:
        var valueIndex = state.index;
        state.index++;
        macro $valuesExpr[$v{valueIndex}];
    };
  }
  static function buildSchemaExpr(schemaExpr:Expr, valuesExpr:Expr, state:{var index:Int;}):Expr {
    var expr = strip(schemaExpr);
    return switch (expr.expr) {
      case EObjectDecl(fields):
        {
          expr: EObjectDecl([
            for (field in fields)
              {
                field: field.field,
                expr: buildSchemaExpr(field.expr, valuesExpr, state),
                quotes: field.quotes
              }
          ]),
          pos: expr.pos
        };
      default:
        var valueIndex = state.index;
        state.index++;
        macro $valuesExpr[$v{valueIndex}];
    };
  }


  static function decodeQuotedComplexType(source:Expr):ComplexType {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Expected a quoted Haxe type", source.pos);
    }
    return switch (parts.name) {
      case "TPath": TPath(decodeQuotedTypePath(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe complex type ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedTypePath(source:Expr):TypePath {
    var pack = new Array<String>();
    var packExpr = objectField(source, "pack");
    if (packExpr != null) {
      for (entry in arrayElements(packExpr)) {
        pack.push(stringLiteral(entry));
      }
    }
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe type path is missing a name", source.pos);
    }
    return {
      pack: pack,
      name: stringLiteral(nameExpr),
      sub: null,
      params: []
    };
  }

  static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _): strip(inner);
      default: expression;
    };
  }

  static function constructorName(source:Expr):String {
    return switch (strip(source).expr) {
      case EConst(CIdent(name)): name;
      case EField(_, field): field;
      default: Context.error("Invalid quoted Haxe enum constructor", source.pos);
    };
  }

  static function constructorParts(source:Expr):Null<{name:String, params:Array<Expr>}> {
    var expr = strip(source);
    return switch (expr.expr) {
      case ECall(callee, params): {name: constructorName(callee), params: params};
      case EConst(CIdent(_)) | EField(_, _): {name: constructorName(expr), params: []};
      default: null;
    };
  }

  static function objectField(source:Expr, name:String):Null<Expr> {
    return switch (strip(source).expr) {
      case EObjectDecl(fields):
        for (field in fields) {
          if (field.field == name) {
            return field.expr;
          }
        }
        null;
      default:
        Context.error("Invalid quoted Haxe object", source.pos);
    };
  }

  static function arrayElements(source:Expr):Array<Expr> {
    return switch (strip(source).expr) {
      case EArrayDecl(values): values;
      default: Context.error("Invalid quoted Haxe array", source.pos);
    };
  }

  static function stringLiteral(source:Expr):String {
    return switch (strip(source).expr) {
      case EConst(CString(value, _)): value;
      default: Context.error("Expected quoted Haxe string literal", source.pos);
    };
  }
}
#end
