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

class StructTensor<S> {
  public static macro function alloc(ctx:haxe.macro.Expr, shape:haxe.macro.Expr, ?layout:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.QdStruct.structTensorAlloc(ctx, shape, layout);
  }

  #if !macro
  public final context:Context;
  public final shape:Array<Int>;
  public final layout:LayoutPolicy;
  public final schema:Dynamic;
  final tensors:Map<String, Dynamic> = [];
  final names:Array<String> = [];

  function new(context:Context, shape:Array<Int>, layout:LayoutPolicy, schema:Dynamic) {
    if (context == null) {
      throw "Quadrants StructTensor requires a Context";
    }
    this.context = context;
    this.shape = TensorStorage.validateShape(shape);
    this.layout = layout;
    this.schema = schema;
    allocateMembers();
  }

  @:noCompletion public static function __create<S>(context:Context, shape:Array<Int>, layout:LayoutPolicy, schema:Dynamic):StructTensor<S> {
    return new StructTensor<S>(context, shape, layout, schema);
  }

  public function length():Int {
    return TensorStorage.elementCount(shape);
  }

  public function members():Array<String> {
    return names.copy();
  }

  public function member<T>(name:String):Tensor<T> {
    var value = tensors.get(name);
    if (value == null) {
      throw 'Quadrants StructTensor member ${name} is missing';
    }
    return cast value;
  }

  public function readMember<T>(name:String, flatIndex:Int):T {
    var tensor:Dynamic = member(name);
    return Reflect.callMethod(tensor, Reflect.field(tensor, "read"), [flatIndex]);
  }

  public function writeMember<T>(name:String, flatIndex:Int, value:T):Void {
    var tensor:Dynamic = member(name);
    Reflect.callMethod(tensor, Reflect.field(tensor, "write"), [flatIndex, value]);
  }

  public function descriptorResource():Dynamic {
    return {
      resourceKind: "StructTensor",
      layout: Std.string(layout),
      shape: shape.copy(),
      schema: schema,
    };
  }

  public function close():Void {
    for (name in names) {
      var tensor:Dynamic = tensors.get(name);
      if (tensor != null) {
        Reflect.callMethod(tensor, Reflect.field(tensor, "close"), []);
      }
    }
    tensors.clear();
    names.resize(0);
  }

  function allocateMembers():Void {
    var fields:Array<Dynamic> = cast Reflect.field(schema, "fields");
    if (fields == null) {
      throw "Quadrants StructTensor schema is missing fields";
    }
    for (field in fields) {
      var name:String = cast Reflect.field(field, "name");
      var dtype:String = cast Reflect.field(field, "dtype");
      var lanesValue:Null<Int> = cast Reflect.field(field, "lanes");
      var lanes = lanesValue == null || lanesValue <= 0 ? 1 : lanesValue;
      var memberShape = shape.copy();
      if (lanes != 1) {
        memberShape.push(lanes);
      }
      tensors.set(name, allocateTensor(dtype, memberShape));
      names.push(name);
    }
  }

  function allocateTensor(dtype:String, memberShape:Array<Int>):Dynamic {
    return switch (dtype) {
      case "i8": new Tensor<I8>(context, memberShape);
      case "i16": new Tensor<I16>(context, memberShape);
      case "i32": new Tensor<I32>(context, memberShape);
      case "i64": new Tensor<I64>(context, memberShape);
      case "u8": new Tensor<U8>(context, memberShape);
      case "u16": new Tensor<U16>(context, memberShape);
      case "u32": new Tensor<U32>(context, memberShape);
      case "u64": new Tensor<U64>(context, memberShape);
      case "u1": new Tensor<U1>(context, memberShape);
      case "f16": new Tensor<F16>(context, memberShape);
      case "f32": new Tensor<F32>(context, memberShape);
      case "f64": new Tensor<F64>(context, memberShape);
      default: throw 'Quadrants StructTensor unsupported member dtype ${dtype}';
    };
  }
  #end
}
