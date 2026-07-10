package quadrants;

#if !macro
import quadrants.Types.F16;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I8;
import quadrants.Types.I16;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U1;
import quadrants.Types.U8;
import quadrants.Types.U16;
import quadrants.Types.U32;
import quadrants.Types.U64;
import quadrants.FieldsBuilder.FieldPlacementEntry;
import quadrants.snode.FieldPlacementPath;
import quadrants.StructSchema.StructMemberSchema;
#end

class StructField<S> {
  public static macro function alloc(ctx:haxe.macro.Expr,
      shape:haxe.macro.Expr,
      ?layout:haxe.macro.Expr,
      ?placement:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.QdStruct.structFieldAlloc(ctx, shape, layout, placement);
  }

  #if !macro
  public final context:Context;
  public final shape:Array<Int>;
  public final layout:LayoutPolicy;
  @:noCompletion public final schema:StructSchema;
  final fields:Map<String, FieldRuntime> = [];
  final laneShapes:Map<String, Array<Int>> = [];
  final names:Array<String> = [];

  function new(context:Context,
      shape:Array<Int>,
      layout:LayoutPolicy,
      schema:StructSchema,
      ?placement:FieldPlacementPath) {
    if (context == null) {
      throw "Quadrants StructField requires a Context";
    }
    this.context = context;
    this.shape = TensorStorage.validateShape(shape);
    this.layout = layout;
    this.schema = schema;
    allocateMembers();
    placeMembers(placement);
  }

  @:noCompletion public static function __create<S>(context:Context,
      shape:Array<Int>,
      layout:LayoutPolicy,
      schema:StructSchema,
      ?placement:FieldPlacementPath):StructField<S> {
    return new StructField<S>(context, shape, layout, schema, placement);
  }

  public function length():Int {
    return TensorStorage.elementCount(shape);
  }

  public function members():Array<String> {
    return names.copy();
  }

  public function member<T>(name:String):Field<T> {
    var value = fields.get(name);
    if (value == null) {
      throw 'Quadrants StructField member ${name} is missing';
    }
    return cast value;
  }

  public function readMember<T>(name:String, flatIndex:Int):T {
    return member(name).read(flatIndex);
  }

  public function writeMember<T>(name:String, flatIndex:Int, value:T):Void {
    member(name).write(flatIndex, value);
  }

  @:noCompletion public function descriptorResource():StructResourceDescriptor {
    return {
      resourceKind: "StructField",
      layout: Std.string(layout),
      shape: shape.copy(),
      schema: schema,
    };
  }

  public function close():Void {
    for (name in names) {
      var field = fields.get(name);
      if (field != null) {
        field.close();
      }
    }
    fields.clear();
    laneShapes.clear();
    names.resize(0);
  }

  function allocateMembers():Void {
    var schemaFields = schema.fields;
    if (schemaFields == null || schemaFields.length == 0) {
      throw "Quadrants StructField schema must declare at least one field";
    }
    for (entry in schemaFields) {
      var name = entry.name;
      if (name == null || name.length == 0) {
        throw "Quadrants StructField schema member name is required";
      }
      if (fields.exists(name)) {
        throw 'Quadrants StructField schema contains duplicate member ${name}';
      }
      fields.set(name, allocateField(entry.dtype));
      laneShapes.set(name, memberLaneShape(entry));
      names.push(name);
    }
  }

  function memberLaneShape(entry:StructMemberSchema):Array<Int> {
    return switch (entry.kind) {
      case "primitive":
        [];
      case "vector":
        if (entry.lanes <= 0) {
          throw 'Quadrants StructField vector member ${entry.name} requires positive lane count';
        }
        [entry.lanes];
      case "matrix":
        if (entry.rows <= 0 || entry.cols <= 0) {
          throw 'Quadrants StructField matrix member ${entry.name} requires positive row and column counts';
        }
        [entry.rows, entry.cols];
      default:
        throw 'Quadrants StructField member ${entry.name} has unsupported placement kind ${entry.kind}';
    };
  }

  function placeMembers(placement:Null<FieldPlacementPath>):Void {
    if (layout != LayoutPolicy.AOS && layout != LayoutPolicy.SOA) {
      throw "Quadrants StructField layout must be AOS or SOA";
    }
    var path = placement == null ? new FieldsBuilder(context).dense(shape).path() : placement;
    if (path.context != context) {
      throw "Quadrants StructField placement path belongs to a different Context";
    }
    TensorStorage.requireSameShape(shape, path.shape, "StructField placement path");

    var entries = new Array<FieldPlacementEntry>();
    for (name in names) {
      var field = fields.get(name);
      var laneShape = laneShapes.get(name);
      if (field == null || laneShape == null) {
        throw 'Quadrants StructField member ${name} has incomplete placement metadata';
      }
      entries.push({
        field: field,
        laneShape: TensorStorage.copyIntArray(laneShape)
      });
    }

    if (layout == LayoutPolicy.AOS) {
      path.placeFieldEntries(entries);
      return;
    }
    for (entry in entries) {
      var individual:Array<FieldPlacementEntry> = [entry];
      path.placeFieldEntries(individual);
    }
  }

  function allocateField(dtype:String):FieldRuntime {
    return switch (dtype) {
      case "i8": cast new Field<I8>(context);
      case "i16": cast new Field<I16>(context);
      case "i32": cast new Field<I32>(context);
      case "i64": cast new Field<I64>(context);
      case "u8": cast new Field<U8>(context);
      case "u16": cast new Field<U16>(context);
      case "u32": cast new Field<U32>(context);
      case "u64": cast new Field<U64>(context);
      case "u1": cast new Field<U1>(context);
      case "f16": cast new Field<F16>(context);
      case "f32": cast new Field<F32>(context);
      case "f64": cast new Field<F64>(context);
      default: throw 'Quadrants StructField unsupported member dtype ${dtype}';
    };
  }
  #end
}
