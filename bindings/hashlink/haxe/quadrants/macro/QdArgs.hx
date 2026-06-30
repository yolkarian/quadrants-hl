package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;

private typedef QdArgsMember = {
  var name:String;
  var type:ComplexType;
  var pos:Position;
  var resource:Bool;
  var spec:Bool;
}

class QdArgs {
  public static function build():Array<Field> {
    var fields = Context.getBuildFields();
    var localRef = Context.getLocalClass();
    if (localRef == null) {
      Context.error("QdArgs.build() must be used on a class", Context.currentPos());
    }
    var local = localRef.get();
    local.meta.add(":qdArgs", [], Context.currentPos());

    var members = new Array<QdArgsMember>();
    var dataNames = new Map<String, Bool>();
    for (field in fields) {
      if (!isInstanceDataField(field) || hasBuildMeta(field.meta, ":hostOnly") || hasBuildMeta(field.meta, "hostOnly") || StringTools.startsWith(field.name, "__qd_")) {
        continue;
      }
      var fieldType = fieldComplexType(field);
      if (fieldType == null) {
        Context.error('Quadrants QdArgs field ${field.name} requires an explicit type annotation', field.pos);
      }
      validateMember(field.name, fieldType, field.pos);
      var resource = isResourceComplexType(fieldType, field.pos);
      members.push({name: field.name, type: fieldType, pos: field.pos, resource: resource, spec: !resource});
      dataNames.set(field.name, true);
    }

    if (!hasField(fields, "__qdContext")) {
      fields.push(contextMethod(local, members));
    }
    if (!hasField(fields, "schema")) {
      fields.push(schemaMethod(local, members));
    }
    if (!hasField(fields, "appendArgs")) {
      fields.push(appendArgsMethod(local, members));
    }
    if (!hasField(fields, "appendSpec")) {
      fields.push(appendSpecMethod(local, members));
    }

    var generatedKernelFields = new Array<Field>();
    for (field in fields) {
      switch (field.kind) {
        case FFun(fun) if (hasBuildMeta(field.meta, ":kernel") || hasBuildMeta(field.meta, "kernel")):
          generatedKernelFields.push(kernelCacheField(field.name, field.pos));
          field.kind = kernelForwarder(local, field.name, fun, dataNames, field.pos);
          field.meta = removeKernelMeta(field.meta);
        default:
      }
    }
    for (generated in generatedKernelFields) {
      fields.push(generated);
    }
    return fields;
  }

  static function validateMember(name:String, type:ComplexType, pos:Position):Void {
    var resolved = Context.resolveType(type, pos);
    if (isDynamicType(resolved)) {
      Context.error('Quadrants QdArgs field ${name} cannot use Dynamic', pos);
    }
    if (isArrayType(resolved)) {
      Context.error('Quadrants QdArgs field ${name} cannot use Array<T>; mark it @:hostOnly if it is host-only state', pos);
    }
    if (isStringType(resolved)) {
      Context.error('Quadrants QdArgs field ${name} cannot use String; mark it @:hostOnly if it is host-only state', pos);
    }
    if (isResourceType(resolved) || isQdArgsType(resolved) || isAllowedSpecType(resolved)) {
      return;
    }
    Context.error('Quadrants QdArgs field ${name} has unsupported type; use Tensor/Field resources, primitive/enum spec constants, nested QdArgs, or @:hostOnly', pos);
  }

  static function contextMethod(local:ClassType, members:Array<QdArgsMember>):Field {
    var pos = Context.currentPos();
    var statements = new Array<Expr>();
    for (member in members) {
      if (!member.resource) {
        continue;
      }
      var access = fieldExpr({expr: EConst(CIdent("this")), pos: pos}, member.name, pos);
      statements.push(macro if ($e{access} != null) return (cast $e{access}).context);
    }
    if (hasInstanceField(local, "ctx")) {
      statements.push(macro if (this.ctx != null) return this.ctx);
    }
    for (member in members) {
      if (member.resource || !isQdArgsComplexType(member.type, member.pos)) {
        continue;
      }
      var access = fieldExpr({expr: EConst(CIdent("this")), pos: pos}, member.name, pos);
      statements.push(macro if ($e{access} != null) return (cast $e{access}).__qdContext());
    }
    statements.push(macro throw "Quadrants QdArgs instance has no resource or ctx field to provide a Context for @:kernel methods");
    return {
      name: "__qdContext",
      access: [APublic],
      kind: FFun({args: [], ret: macro : quadrants.Context, expr: {expr: EBlock(statements), pos: pos}, params: []}),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function schemaMethod(local:ClassType, members:Array<QdArgsMember>):Field {
    var pos = Context.currentPos();
    var fieldEntries = [for (member in members) macro {name: $v{member.name}, role: $v{member.resource ? "runtime" : "spec"}}];
    var fieldsExpr:Expr = {expr: EArrayDecl(fieldEntries), pos: pos};
    return {
      name: "schema",
      access: [APublic, AStatic],
      kind: FFun({args: [], ret: macro : Dynamic, expr: macro return {version: 3, kind: "QdArgs", fields: $e{fieldsExpr}}, params: []}),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function appendArgsMethod(local:ClassType, members:Array<QdArgsMember>):Field {
    var pos = Context.currentPos();
    var valueType = classComplexType(local);
    var statements = new Array<Expr>();
    for (member in members) {
      if (member.resource) {
        statements.push(macro quadrants.kernel.ArgEncoding.append(buf, $e{fieldExpr({expr: EConst(CIdent("value")), pos: pos}, member.name, pos)}));
      }
    }
    statements.push(macro return);
    return {
      name: "appendArgs",
      access: [APublic, AStatic],
      kind: FFun({args: [
        {name: "buf", opt: false, type: macro : quadrants.kernel.ArgBuffer, value: null},
        {name: "value", opt: false, type: valueType, value: null},
      ], ret: macro : Void, expr: {expr: EBlock(statements), pos: pos}, params: []}),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function appendSpecMethod(local:ClassType, members:Array<QdArgsMember>):Field {
    var pos = Context.currentPos();
    var valueType = classComplexType(local);
    var statements = new Array<Expr>();
    for (member in members) {
      if (member.spec) {
        statements.push(macro key.addTemplate($v{member.name}, $e{fieldExpr({expr: EConst(CIdent("value")), pos: pos}, member.name, pos)}));
      }
    }
    statements.push(macro return);
    return {
      name: "appendSpec",
      access: [APublic, AStatic],
      kind: FFun({args: [
        {name: "key", opt: false, type: macro : quadrants.flatten.SpecKey, value: null},
        {name: "value", opt: false, type: valueType, value: null},
      ], ret: macro : Void, expr: {expr: EBlock(statements), pos: pos}, params: []}),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function kernelCacheField(methodName:String, pos:Position):Field {
    return {
      name: '__qd_${methodName}Kernel',
      access: [APrivate],
      kind: FVar(macro : Dynamic, macro null),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function kernelForwarder(local:ClassType, methodName:String, fun:Function, dataNames:Map<String, Bool>, pos:Position):FieldType {
    var selfArg:FunctionArg = {name: "self", opt: false, type: classComplexType(local), value: null};
    var kernelArgs = [selfArg].concat([for (arg in fun.args) {name: arg.name, opt: arg.opt, type: arg.type, value: arg.value}]);
    var shadowed = new Map<String, Bool>();
    for (arg in fun.args) {
      shadowed.set(arg.name, true);
    }
    var rewrittenBody = rewriteKernelMethodBody(fun.expr, dataNames, shadowed);
    var kernelFunction:Expr = {expr: EFunction(FAnonymous, {args: kernelArgs, ret: fun.ret, expr: rewrittenBody, params: []}), pos: pos};
    var cacheName = '__qd_${methodName}Kernel';
    var launchArgs = [macro this].concat([for (arg in fun.args) ({expr: EConst(CIdent(arg.name)), pos: pos} : Expr)]);
    var cacheAccess = fieldExpr({expr: EConst(CIdent("this")), pos: pos}, cacheName, pos);
    var returnType = fun.ret == null ? macro : Void : fun.ret;
    var body = if (isVoidComplexType(returnType)) {
      macro {
        if ($e{cacheAccess} == null) {
          $e{cacheAccess} = quadrants.Kernel.build(this.__qdContext(), $e{kernelFunction}, {name: $v{local.name + "." + methodName}});
        }
        $e{cacheAccess}.launch($a{launchArgs});
      };
    } else {
      macro {
        if ($e{cacheAccess} == null) {
          $e{cacheAccess} = quadrants.Kernel.build(this.__qdContext(), $e{kernelFunction}, {name: $v{local.name + "." + methodName}});
        }
        return $e{cacheAccess}.launch($a{launchArgs});
      };
    };
    return FFun({args: fun.args, ret: returnType, expr: body, params: fun.params});
  }

  static function rewriteKernelMethodBody(expr:Expr, dataNames:Map<String, Bool>, shadowed:Map<String, Bool>):Expr {
    if (expr == null) {
      return null;
    }
    return switch (expr.expr) {
      case EConst(CIdent(name)) if (dataNames.exists(name) && !shadowed.exists(name)):
        fieldExpr({expr: EConst(CIdent("self")), pos: expr.pos}, name, expr.pos);
      case EConst(CIdent("this")):
        {expr: EConst(CIdent("self")), pos: expr.pos};
      case EField(base, field):
        {expr: EField(rewriteKernelMethodBody(base, dataNames, shadowed), field), pos: expr.pos};
      case EBlock(expressions):
        var localShadowed = cloneMap(shadowed);
        var rewritten = new Array<Expr>();
        for (entry in expressions) {
          var next = rewriteKernelMethodBody(entry, dataNames, localShadowed);
          rewritten.push(next);
          shadowDeclared(localShadowed, next);
        }
        {expr: EBlock(rewritten), pos: expr.pos};
      case EVars(vars):
        {
          expr: EVars([
            for (variable in vars)
              {
                name: variable.name,
                type: variable.type,
                expr: variable.expr == null ? null : rewriteKernelMethodBody(variable.expr, dataNames, shadowed),
                isFinal: variable.isFinal,
                meta: variable.meta,
              }
          ]),
          pos: expr.pos,
        };
      case EFor(iterator, body):
        var localShadowed = cloneMap(shadowed);
        shadowForIterator(localShadowed, iterator);
        {expr: EFor(rewriteKernelMethodBody(iterator, dataNames, shadowed), rewriteKernelMethodBody(body, dataNames, localShadowed)), pos: expr.pos};
      case EFunction(kind, nested):
        var localShadowed = cloneMap(shadowed);
        for (arg in nested.args) {
          localShadowed.set(arg.name, true);
        }
        {expr: EFunction(kind, {args: nested.args, ret: nested.ret, expr: rewriteKernelMethodBody(nested.expr, dataNames, localShadowed), params: nested.params}), pos: expr.pos};
      default:
        ExprTools.map(expr, function(next) return rewriteKernelMethodBody(next, dataNames, shadowed));
    };
  }

  static function shadowDeclared(scope:Map<String, Bool>, expr:Expr):Void {
    switch (expr.expr) {
      case EVars(vars):
        for (variable in vars) {
          scope.set(variable.name, true);
        }
      default:
    }
  }

  static function shadowForIterator(scope:Map<String, Bool>, iterator:Expr):Void {
    switch (iterator.expr) {
      case EBinop(OpIn, lhs, _):
        switch (lhs.expr) {
          case EConst(CIdent(name)): scope.set(name, true);
          default:
        }
      default:
    }
  }

  static function cloneMap(source:Map<String, Bool>):Map<String, Bool> {
    var result = new Map<String, Bool>();
    for (key in source.keys()) {
      result.set(key, true);
    }
    return result;
  }

  static function classComplexType(local:ClassType):ComplexType {
    return TPath({pack: local.pack, name: local.name, params: []});
  }

  static function isVoidComplexType(type:ComplexType):Bool {
    return switch (type) {
      case TParent(inner): isVoidComplexType(inner);
      case TPath(path): typePathName(path) == "Void" || typePathName(path) == "StdTypes.Void";
      default: false;
    };
  }

  static function typePathName(path:TypePath):String {
    return (path.pack.length == 0 ? "" : path.pack.join(".") + ".") + path.name + (path.sub == null ? "" : "." + path.sub);
  }

  static function fieldExpr(base:Expr, name:String, pos:Position):Expr {
    return {expr: EField(base, name), pos: pos};
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

  static function fieldComplexType(field:Field):Null<ComplexType> {
    return switch (field.kind) {
      case FVar(type, _): type;
      case FProp(_, _, type, _): type;
      default: null;
    };
  }

  static function hasField(fields:Array<Field>, name:String):Bool {
    for (field in fields) {
      if (field.name == name) {
        return true;
      }
    }
    return false;
  }

  static function hasInstanceField(local:ClassType, name:String):Bool {
    for (field in local.fields.get()) {
      if (field.name == name) {
        return true;
      }
    }
    return false;
  }

  static function hasBuildMeta(meta:Metadata, name:String):Bool {
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

  static function removeKernelMeta(meta:Metadata):Metadata {
    if (meta == null) {
      return [];
    }
    return [for (entry in meta) if (entry.name != ":kernel" && entry.name != "kernel") entry];
  }

  static function isResourceComplexType(type:ComplexType, pos:Position):Bool {
    return isResourceType(Context.resolveType(type, pos));
  }

  static function isQdArgsComplexType(type:ComplexType, pos:Position):Bool {
    return isQdArgsType(Context.resolveType(type, pos));
  }

  static function isResourceType(type:Type):Bool {
    return switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _):
        var cls = classRef.get();
        var name = cls.name;
        name == "Tensor" || name == "Field" || name == "TensorArg" || name == "FieldArg" || StringTools.startsWith(cls.pack.join(".") + "." + name, "quadrants._generated.Tensor_") || StringTools.startsWith(cls.pack.join(".") + "." + name, "quadrants._generated.Field_");
      default:
        false;
    };
  }

  static function isQdArgsType(type:Type):Bool {
    return switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _):
        var cls = classRef.get();
        cls.meta.extract(":qdArgs").length > 0 || cls.meta.extract("qdArgs").length > 0;
      default:
        false;
    };
  }

  static function isAllowedSpecType(type:Type):Bool {
    return switch (Context.followWithAbstracts(type)) {
      case TAbstract(_, _): true;
      case TEnum(_, _): true;
      default: false;
    };
  }

  static function isArrayType(type:Type):Bool {
    return switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _): classRef.get().pack.join(".") == "" && classRef.get().name == "Array";
      default: false;
    };
  }

  static function isStringType(type:Type):Bool {
    return switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _): classRef.get().pack.join(".") == "" && classRef.get().name == "String";
      default: false;
    };
  }

  static function isDynamicType(type:Type):Bool {
    return switch (Context.follow(type)) {
      case TDynamic(_): true;
      default: false;
    };
  }
}
#end
