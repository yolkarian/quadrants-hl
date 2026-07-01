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
#end

class StructField<S> {
  public static macro function alloc(ctx:haxe.macro.Expr, shape:haxe.macro.Expr, ?layout:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.QdStruct.structFieldAlloc(ctx, shape, layout);
  }

  #if !macro
  public final context:Context;
  public final shape:Array<Int>;
  public final layout:LayoutPolicy;
  @:noCompletion public final schema:StructSchema;
  final fields:Map<String, Dynamic> = [];
  final names:Array<String> = [];

  function new(context:Context, shape:Array<Int>, layout:LayoutPolicy, schema:StructSchema) {
    if (context == null) {
      throw "Quadrants StructField requires a Context";
    }
    this.context = context;
    this.shape = TensorStorage.validateShape(shape);
    this.layout = layout;
    this.schema = schema;
    allocateMembers();
  }

  @:noCompletion public static function __create<S>(context:Context, shape:Array<Int>, layout:LayoutPolicy, schema:StructSchema):StructField<S> {
    return new StructField<S>(context, shape, layout, schema);
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
    var field:Dynamic = member(name);
    return Reflect.callMethod(field, Reflect.field(field, "read"), [flatIndex]);
  }

  public function writeMember<T>(name:String, flatIndex:Int, value:T):Void {
    var field:Dynamic = member(name);
    Reflect.callMethod(field, Reflect.field(field, "write"), [flatIndex, value]);
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
      var field:Dynamic = fields.get(name);
      if (field != null) {
        Reflect.callMethod(field, Reflect.field(field, "close"), []);
      }
    }
    fields.clear();
    names.resize(0);
  }

  function allocateMembers():Void {
    var schemaFields = schema.fields;
    if (schemaFields == null) {
      throw "Quadrants StructField schema is missing fields";
    }
    for (entry in schemaFields) {
      var name = entry.name;
      var dtype = entry.dtype;
      var lanesValue:Null<Int> = entry.lanes;
      var lanes = lanesValue == null || lanesValue <= 0 ? 1 : lanesValue;
      var memberShape = shape.copy();
      if (lanes != 1) {
        memberShape.push(lanes);
      }
      fields.set(name, allocateField(dtype, memberShape));
      names.push(name);
    }
  }

  function allocateField(dtype:String, memberShape:Array<Int>):Dynamic {
    return switch (dtype) {
      case "i8": new Field<I8>(context, memberShape);
      case "i16": new Field<I16>(context, memberShape);
      case "i32": new Field<I32>(context, memberShape);
      case "i64": new Field<I64>(context, memberShape);
      case "u8": new Field<U8>(context, memberShape);
      case "u16": new Field<U16>(context, memberShape);
      case "u32": new Field<U32>(context, memberShape);
      case "u64": new Field<U64>(context, memberShape);
      case "u1": new Field<U1>(context, memberShape);
      case "f16": new Field<F16>(context, memberShape);
      case "f32": new Field<F32>(context, memberShape);
      case "f64": new Field<F64>(context, memberShape);
      default: throw 'Quadrants StructField unsupported member dtype ${dtype}';
    };
  }
  #end
}
