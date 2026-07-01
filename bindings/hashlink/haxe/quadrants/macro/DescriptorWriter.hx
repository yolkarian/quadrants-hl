package quadrants.macro;

#if macro
import haxe.Json;
import quadrants.macro.DescriptorMetadata.QdhlMetaArgEntry;
import quadrants.macro.DescriptorMetadata.QdhlMetaResourceEntry;
import quadrants.macro.DescriptorMetadata.QdhlParamMeta;
import quadrants.macro.DescriptorMetadata.QdhlSpecMeta;
import quadrants.macro.StructTableBuilder.StructTableEntry;
import quadrants.macro.TypeTableBuilder.TypeTableEntry;

private class QdhlAttributeWriter {
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

class DescriptorWriter {
  public static inline var SCHEMA_VERSION:Int = 3;

  public static function autoMetadata(kernelName:String, params:Array<QdhlParamMeta>):String {
    return metadata(kernelName, params, [], [], []);
  }

  public static function metadata(kernelName:String,
      params:Array<QdhlParamMeta>,
      templates:Array<QdhlSpecMeta>,
      structs:Array<StructTableEntry>,
      requirements:Array<String>):String {
    var typeIds = new Map<String, Int>();
    var types:Array<TypeTableEntry> = [];
    var args:Array<QdhlMetaArgEntry> = [];
    var resources:Array<QdhlMetaResourceEntry> = [];
    var specTable:Array<QdhlSpecMeta> = templates == null ? [] : templates.copy();
    var structTable:Array<StructTableEntry> = structs == null ? [] : structs.copy();
    var capabilities:Array<String> = requirements == null ? [] : requirements.copy();

    function ensureCapability(name:String):Void {
      if (capabilities.indexOf(name) < 0) {
        capabilities.push(name);
      }
    }

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
        case 3: "mesh_relation";
        case 4: "mesh_attribute";
        default: 'unknown(${kind})';
      };
    }

    function typeKind(kind:Int, role:String):String {
      return switch (kind) {
        case 0: role == "spec" || role == "template" ? "spec" : "primitive";
        case 1: "tensor_resource";
        case 2: "field_resource";
        case 3: "mesh_relation_resource";
        case 4: "mesh_attribute_resource";
        default: "primitive";
      };
    }

    function argKind(role:String, kind:Int):String {
      if (role == "spec" || role == "template") {
        return "SpecConstant";
      }
      return kind == 0 ? "RuntimeScalar" : "RuntimeResource";
    }

    function typeIdOf(kind:Int, dtype:Int, rank:Int, role:String):Int {
      var key = kind + ":" + dtype + ":" + rank + ":" + role;
      var existing = typeIds.get(key);
      if (existing != null) {
        return existing;
      }
      var id = types.length + 1;
      typeIds.set(key, id);
      types.push({id: id, kind: typeKind(kind, role), dtype: dtypeName(dtype), rank: rank});
      return id;
    }

    for (index in 0...params.length) {
      var param = params[index];
      var kind = param.kind;
      var dtype = param.dtype;
      var rank = param.rank;
      var path = param.path;
      var role = param.role == null ? "runtime" : param.role;
      var typeId = typeIdOf(kind, dtype, rank, role);
      args.push({
        index: index,
        name: path,
        sourcePath: path,
        path: path,
        role: role,
        kind: kindName(kind),
        argKind: argKind(role, kind),
        typeId: typeId,
        access: "ReadWrite",
      });
      if (role == "spec" || role == "template") {
        specTable.push({path: path, type: dtypeName(dtype), value: "launch"});
        ensureCapability("template_constants");
      }
      if (kind != 0) {
        resources.push({path: path, resourceKind: kindName(kind), kind: kindName(kind), typeId: typeId, rank: rank, layout: "default"});
      }
      if (kind == 2) {
        ensureCapability("field_resource_param");
      }
      if (kind == 3) {
        ensureCapability("mesh_kernel_relations");
      }
      if (kind == 4) {
        ensureCapability("mesh_kernel_attributes");
      }
    }

    return Json.stringify({
      header: {
        magic: "QDHL",
        schemaVersion: SCHEMA_VERSION,
        producer: "haxe-hl",
        descriptorHash: "computed-by-runtime"
      },
      version: SCHEMA_VERSION,
      kernelName: kernelName,
      typeTable: types,
      types: types,
      argTable: args,
      args: args,
      resourceTable: resources,
      resources: resources,
      structTable: structTable,
      specTable: specTable,
      templates: specTable,
      capabilityRequirements: capabilities,
      capabilities: capabilities,
      debugInfo: {}
    });
  }

  public static function attributesSection(metadataJson:String):Array<Int> {
    var writer = new QdhlAttributeWriter();
    writer.u32(1);
    writer.string("qdhl.meta.json");
    writer.string(metadataJson);
    return writer.bytes;
  }
}
#end
