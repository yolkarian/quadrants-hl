package quadrants.macro;

#if macro
import haxe.Json;

private class AttributeWriter {
  public final bytes:Array<Int> = [];

  public function new() {}

  public function u8(value:Int):Void {
    bytes.push(value & 0xff);
  }

  public function u32(value:Int):Void {
    u8(value);
    u8(value >>> 8);
    u8(value >>> 16);
    u8(value >>> 24);
  }

  public function string(value:String):Void {
    var encoded = haxe.io.Bytes.ofString(value);
    u32(encoded.length);
    for (i in 0...encoded.length) {
      u8(encoded.get(i));
    }
  }
}

class DescriptorV2Writer {
  public static function autoMetadata(kernelName:String, params:Array<Dynamic>):String {
    var typeIds = new Map<String, Int>();
    var types:Array<Dynamic> = [];
    var args:Array<Dynamic> = [];
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

    for (index in 0...params.length) {
      var param = params[index];
      var kind:Int = Reflect.field(param, "kind");
      var dtype:Int = Reflect.field(param, "dtype");
      var rank:Int = Reflect.field(param, "rank");
      var name:String = Reflect.field(param, "name");
      var typeId = typeIdOf(kind, dtype, rank);
      args.push({index: index, path: name, role: "runtime", kind: kindName(kind), typeId: typeId});
      if (kind != 0) {
        resources.push({path: name, kind: kindName(kind), typeId: typeId});
      }
      if (kind == 2 && capabilities.indexOf("field_direct_param") < 0) {
        capabilities.push("field_direct_param");
      }
    }

    return Json.stringify({
      version: 2,
      kernelName: kernelName,
      types: types,
      args: args,
      templates: [],
      resources: resources,
      capabilities: capabilities,
    });
  }

  public static function attributesSection(metadataJson:String):Array<Int> {
    var writer = new AttributeWriter();
    writer.u32(1);
    writer.string("qdhl.meta.json");
    writer.string(metadataJson);
    return writer.bytes;
  }
}
#end
