package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.TypeTools;

private typedef StructMemberInfo = {
  var name:String;
  var type:ComplexType;
  var kind:String;
  var dtype:String;
  var lanes:Int;
  var rows:Int;
  var cols:Int;
  var offset:Int;
  var align:Int;
  var size:Int;
}

class QdStruct {
  public static function build():Array<Field> {
    var fields = Context.getBuildFields();
    var localRef = Context.getLocalClass();
    if (localRef == null) {
      Context.error("QdStruct.build() must be used on a class", Context.currentPos());
    }
    var local = localRef.get();
    local.meta.add(":qdStruct", [], Context.currentPos());

    var members = new Array<StructMemberInfo>();
    var layout = collectBuildMembers(fields, "", 0, members);
    var sizeBytes = alignTo(layout.offset, layout.align);
    var maxAlign = layout.align;

    if (!hasField(fields, "__qdStructSchema")) {
      fields.push(schemaField(local, members, sizeBytes, maxAlign));
    }
    if (!hasField(fields, "__qdIsStruct")) {
      fields.push(isStructField());
    }
    return fields;
  }

  public static function structTensorAlloc(ctx:Expr, shape:Expr, layout:Null<Expr>):Expr {
    var structType = expectedStructArg("StructTensor", Context.currentPos());
    var schema = schemaCall(structType, Context.currentPos());
    var layoutExpr = layout == null ? macro quadrants.LayoutPolicy.AOS : layout;
    return macro cast quadrants.StructTensor.__create($e{ctx}, $e{shape}, $e{layoutExpr}, $e{schema});
  }

  public static function structFieldAlloc(ctx:Expr, shape:Expr, layout:Null<Expr>):Expr {
    var structType = expectedStructArg("StructField", Context.currentPos());
    var schema = schemaCall(structType, Context.currentPos());
    var layoutExpr = layout == null ? macro quadrants.LayoutPolicy.SOA : layout;
    return macro cast quadrants.StructField.__create($e{ctx}, $e{shape}, $e{layoutExpr}, $e{schema});
  }

  static function expectedStructArg(containerName:String, pos:Position):Type {
    var expected = Context.getExpectedType();
    if (expected == null) {
      Context.error('Quadrants ${containerName}.alloc requires an expected type ${containerName}<S>; annotate the receiving variable', pos);
    }
    return switch (Context.followWithAbstracts(expected)) {
      case TInst(classRef, params):
        var cls = classRef.get();
        if (cls.pack.join(".") == "quadrants" && cls.name == containerName && params.length == 1) {
          validateStructType(params[0], pos);
          params[0];
        } else {
          Context.error('Quadrants ${containerName}.alloc requires an expected type ${containerName}<S>', pos);
        }
      default:
        Context.error('Quadrants ${containerName}.alloc requires an expected type ${containerName}<S>', pos);
    };
  }

  static function validateStructType(type:Type, pos:Position):Void {
    switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _):
        var cls = classRef.get();
        if (cls.meta.extract(":qdStruct").length == 0 && cls.meta.extract("qdStruct").length == 0) {
          Context.error('StructTensor/StructField element type ${cls.name} must use @:build(quadrants.macro.QdStruct.build())', pos);
        }
      default:
        Context.error("StructTensor/StructField element type must be a QdStruct class", pos);
    }
  }

  static function schemaCall(type:Type, pos:Position):Expr {
    return switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _):
        var cls = classRef.get();
        var path:Expr = null;
        for (part in cls.pack) {
          path = path == null ? ({expr: EConst(CIdent(part)), pos: pos} : Expr) : ({expr: EField(path, part), pos: pos} : Expr);
        }
        path = path == null ? ({expr: EConst(CIdent(cls.name)), pos: pos} : Expr) : ({expr: EField(path, cls.name), pos: pos} : Expr);
        {expr: ECall({expr: EField(path, "__qdStructSchema"), pos: pos}, []), pos: pos};
      default:
        Context.error("QdStruct schema expects a class type", pos);
    };
  }

  static function collectBuildMembers(fields:Array<Field>, prefix:String, offset:Int, members:Array<StructMemberInfo>):{offset:Int, align:Int} {
    var currentOffset = offset;
    var maxAlign = 1;
    for (field in fields) {
      if (!isInstanceVar(field)) {
        continue;
      }
      var type = fieldType(field);
      if (type == null) {
        Context.error('Quadrants QdStruct field ${field.name} requires an explicit type annotation', field.pos);
      }
      var nested = nestedStructClass(type, field.pos);
      if (nested != null) {
        var nestedLayout = collectClassMembers(nested, prefix + field.name + ".", currentOffset, members, field.pos);
        currentOffset = nestedLayout.offset;
        if (nestedLayout.align > maxAlign) maxAlign = nestedLayout.align;
      } else {
        var info = memberInfo(prefix + field.name, type, field.pos, currentOffset);
        currentOffset = info.offset + info.size;
        if (info.align > maxAlign) maxAlign = info.align;
        members.push(info);
      }
    }
    return {offset: currentOffset, align: maxAlign};
  }

  static function collectClassMembers(cls:ClassType, prefix:String, offset:Int, members:Array<StructMemberInfo>, pos:Position):{offset:Int, align:Int} {
    var currentOffset = offset;
    var maxAlign = 1;
    for (field in cls.fields.get()) {
      if (!field.isPublic) {
        continue;
      }
      var type = TypeTools.toComplexType(field.type);
      var nested = nestedStructClass(type, pos);
      if (nested != null) {
        var nestedLayout = collectClassMembers(nested, prefix + field.name + ".", currentOffset, members, pos);
        currentOffset = nestedLayout.offset;
        if (nestedLayout.align > maxAlign) maxAlign = nestedLayout.align;
      } else {
        var info = memberInfo(prefix + field.name, type, pos, currentOffset);
        currentOffset = info.offset + info.size;
        if (info.align > maxAlign) maxAlign = info.align;
        members.push(info);
      }
    }
    return {offset: currentOffset, align: maxAlign};
  }

  static function nestedStructClass(type:ComplexType, pos:Position):Null<ClassType> {
    return switch (Context.followWithAbstracts(Context.resolveType(type, pos))) {
      case TInst(classRef, _):
        var cls = classRef.get();
        cls.meta.extract(":qdStruct").length > 0 || cls.meta.extract("qdStruct").length > 0 ? cls : null;
      default:
        null;
    };
  }

  static function schemaField(local:ClassType, members:Array<StructMemberInfo>, sizeBytes:Int, alignBytes:Int):Field {
    var pos = Context.currentPos();
    var memberExprs = [for (member in members) macro {
      name: $v{member.name},
      kind: $v{member.kind},
      dtype: $v{member.dtype},
      lanes: $v{member.lanes},
      rows: $v{member.rows},
      cols: $v{member.cols},
      offset: $v{member.offset},
      align: $v{member.align},
      size: $v{member.size}
    }];
    var membersArray:Expr = {expr: EArrayDecl(memberExprs), pos: pos};
    var fullName = (local.pack.length == 0 ? "" : local.pack.join(".") + ".") + local.name;
    return {
      name: "__qdStructSchema",
      access: [APublic, AStatic],
      kind: FFun({args: [], ret: macro : Dynamic, expr: macro return {
        version: 3,
        name: $v{fullName},
        layoutPolicy: "Default",
        sizeBytes: $v{sizeBytes},
        alignBytes: $v{alignBytes},
        fields: $e{membersArray}
      }, params: []}),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function isStructField():Field {
    var pos = Context.currentPos();
    return {
      name: "__qdIsStruct",
      access: [APublic, AStatic, AInline],
      kind: FFun({args: [], ret: macro : Bool, expr: macro return true, params: []}),
      pos: pos,
      meta: [{name: ":noCompletion", params: [], pos: pos}],
    };
  }

  static function memberInfo(name:String, type:ComplexType, pos:Position, nextOffset:Int):StructMemberInfo {
    var resolved = Context.resolveType(type, pos);
    if (isDynamicType(resolved)) {
      Context.error('Quadrants QdStruct field ${name} cannot use Dynamic', pos);
    }
    if (isArrayType(resolved)) {
      Context.error('Quadrants QdStruct field ${name} cannot use Array<T>', pos);
    }
    if (isStringType(resolved)) {
      Context.error('Quadrants QdStruct field ${name} cannot use String', pos);
    }
    if (isResourceType(resolved)) {
      Context.error('Quadrants QdStruct field ${name} cannot use Tensor/Field resources', pos);
    }
    var classified = classify(type, resolved, pos);
    var align = classified.align;
    var offset = alignTo(nextOffset, align);
    return {
      name: name,
      type: type,
      kind: classified.kind,
      dtype: classified.dtype,
      lanes: classified.lanes,
      rows: classified.rows,
      cols: classified.cols,
      offset: offset,
      align: align,
      size: classified.size,
    };
  }

  static function classify(type:ComplexType, resolved:Type, pos:Position):{kind:String, dtype:String, lanes:Int, rows:Int, cols:Int, size:Int, align:Int} {
    return switch (Context.followWithAbstracts(resolved)) {
      case TAbstract(absRef, _):
        var dtype = dtypeName(absRef.get().name);
        if (dtype == null) {
          Context.error('Quadrants QdStruct unsupported primitive type ${absRef.get().name}', pos);
        }
        var bytes = dtypeBytes(dtype);
        {kind: "primitive", dtype: dtype, lanes: 1, rows: 1, cols: 1, size: bytes, align: bytes};
      case TInst(classRef, params):
        var cls = classRef.get();
        var name = cls.name;
        if (isVecName(name) || isMatName(name)) {
          var dtype = if (params.length == 0) {
            "f32";
          } else if (params.length == 1) switch (params[0]) {
            case TInst(paramCls, _): dtypeName(paramCls.get().name);
            case TAbstract(paramAbs, _): dtypeName(paramAbs.get().name);
            default: null;
          } else {
            Context.error('Quadrants QdStruct ${name} member requires zero or one dtype type parameter', pos);
          };
          if (dtype == null) {
            Context.error('Quadrants QdStruct ${name} member has unsupported element dtype', pos);
          }
          var lanes = vectorLanes(name);
          var rows = matrixRows(name);
          var cols = matrixCols(name);
          var count = isVecName(name) ? lanes : rows * cols;
          var elemBytes = dtypeBytes(dtype);
          {kind: isVecName(name) ? "vector" : "matrix", dtype: dtype, lanes: count, rows: rows, cols: cols, size: elemBytes * count, align: elemBytes};
        } else if (cls.meta.extract(":qdStruct").length > 0 || cls.meta.extract("qdStruct").length > 0) {
          var schema = Reflect.field(cls, "name");
          {kind: "struct", dtype: name, lanes: 1, rows: 1, cols: 1, size: 0, align: 1};
        } else {
          Context.error('Quadrants QdStruct field type ${name} is not a POD struct member type', pos);
        }
      default:
        Context.error("Quadrants QdStruct member type is not supported", pos);
    };
  }

  static function dtypeName(name:String):Null<String> {
    return switch (name) {
      case "I8": "i8";
      case "I16": "i16";
      case "I32" | "Int": "i32";
      case "I64": "i64";
      case "U8": "u8";
      case "U16": "u16";
      case "U32" | "UInt": "u32";
      case "U64": "u64";
      case "U1" | "Bool": "u1";
      case "F16": "f16";
      case "F32" | "Single": "f32";
      case "F64" | "Float": "f64";
      default: null;
    };
  }

  static function dtypeBytes(dtype:String):Int {
    return switch (dtype) {
      case "i8" | "u8" | "u1": 1;
      case "i16" | "u16" | "f16": 2;
      case "i32" | "u32" | "f32": 4;
      case "i64" | "u64" | "f64": 8;
      default: 4;
    };
  }

  static function isVecName(name:String):Bool return name == "Vec2" || name == "Vec3" || name == "Vec4";
  static function isMatName(name:String):Bool return name == "Mat2" || name == "Mat3" || name == "Mat4";
  static function vectorLanes(name:String):Int return name == "Vec2" ? 2 : name == "Vec3" ? 3 : name == "Vec4" ? 4 : 1;
  static function matrixRows(name:String):Int return name == "Mat2" ? 2 : name == "Mat3" ? 3 : name == "Mat4" ? 4 : 1;
  static function matrixCols(name:String):Int return matrixRows(name);
  static function alignTo(value:Int, align:Int):Int return align <= 1 ? value : Std.int((value + align - 1) / align) * align;

  static function isInstanceVar(field:Field):Bool {
    if (field.access != null) {
      for (access in field.access) if (access == AStatic) return false;
    }
    return switch (field.kind) {
      case FVar(_, _): true;
      default: false;
    };
  }

  static function fieldType(field:Field):Null<ComplexType> {
    return switch (field.kind) {
      case FVar(type, _): type;
      default: null;
    };
  }

  static function hasField(fields:Array<Field>, name:String):Bool {
    for (field in fields) if (field.name == name) return true;
    return false;
  }

  static function isResourceType(type:Type):Bool {
    return switch (Context.followWithAbstracts(type)) {
      case TInst(classRef, _):
        var cls = classRef.get();
        var name = cls.name;
        var fullName = (cls.pack.length == 0 ? "" : cls.pack.join(".") + ".") + name;
        name == "Tensor" || name == "Field" || name == "StructTensor" || name == "StructField" || name == "TensorArg" || name == "FieldArg"
          || StringTools.startsWith(fullName, "quadrants._generated.Tensor_") || StringTools.startsWith(fullName, "quadrants._generated.Field_");
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
