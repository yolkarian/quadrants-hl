package descriptor;

import haxe.Json;
import quadrants.Context;
import quadrants.Diagnostics;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.LayoutPolicy;
import quadrants.Spec;
import quadrants.StructTensor;
import quadrants.Tensor;
import quadrants.Vec3;
import quadrants.kernel.QKernel;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.I32;

@:build(quadrants.macro.QdStruct.build())
class DescriptorGoldenParticle {
  public var id:I32;
  public var mass:F32;
  public var pos:Vec3;
}

typedef DescriptorGoldenCase = {
  var path:String;
  var kernel:QKernel;
}

class DescriptorGoldenSnapshot {
  static inline var GOLDEN_DIR = "tests/hashlink/descriptor/golden";

  static function dynArray(value:Dynamic):Array<Dynamic> {
    return value == null ? [] : cast value;
  }

  static function field(entry:Dynamic, name:String):String {
    var value = Reflect.field(entry, name);
    return value == null ? "null" : Std.string(value);
  }

  static function stringArray(items:Array<String>):String {
    return "[" + [for (item in items) Json.stringify(item)].join(",") + "]";
  }

  static function metadataArray(meta:Dynamic, name:String):Array<Dynamic> {
    return meta == null ? [] : dynArray(Reflect.field(meta, name));
  }

  static function normalize(kernel:QKernel):String {
    var dump:Dynamic = Diagnostics.dumpDescriptor(kernel);
    var meta:Dynamic = Reflect.field(dump, "descriptor");
    var sections = [for (section in dynArray(Reflect.field(dump, "sections"))) '${field(section, "kind")}:${field(section, "name")}'];
    var parameters = [for (param in dynArray(Reflect.field(dump, "parameters"))) '${field(param, "name")}:${field(param, "kind")}:${field(param, "dtype")}:rank=${field(param, "rank")}:flags=${field(param, "flags")}'];
    var types = [for (type in dynArray(Reflect.field(dump, "typeTable"))) '${field(type, "id")}:${field(type, "kind")}:${field(type, "dtype")}:rank=${field(type, "rank")}:flags=${field(type, "flags")}:struct=${field(type, "structId")}'];
    var args = [for (arg in dynArray(Reflect.field(dump, "argTable"))) '${field(arg, "parameterIndex")}:${field(arg, "name")}:${field(arg, "kind")}:type=${field(arg, "typeId")}:flags=${field(arg, "flags")}'];
    var resources = [for (resource in dynArray(Reflect.field(dump, "resourceTable"))) '${field(resource, "parameterIndex")}:${field(resource, "name")}:${field(resource, "kind")}:rank=${field(resource, "rank")}:type=${field(resource, "typeId")}:flags=${field(resource, "flags")}'];
    var specs = [for (spec in dynArray(Reflect.field(dump, "specTable"))) '${field(spec, "parameterIndex")}:${field(spec, "name")}:${field(spec, "dtype")}:type=${field(spec, "typeId")}:flags=${field(spec, "flags")}'];
    var structs = [for (entry in dynArray(Reflect.field(dump, "structTable"))) {
      var fields = [for (member in dynArray(Reflect.field(entry, "fields"))) '${field(member, "name")}:type=${field(member, "typeId")}:offset=${field(member, "offset")}'];
      '${field(entry, "id")}:${field(entry, "name")}:size=${field(entry, "sizeBytes")}:align=${field(entry, "alignBytes")}:fields=${fields.join("|")}';
    }];
    var metaArgs = [for (arg in metadataArray(meta, "args")) '${field(arg, "path")}:${field(arg, "argKind")}:${field(arg, "kind")}:type=${field(arg, "typeId")}'];
    var metaResources = [for (resource in metadataArray(meta, "resources")) '${field(resource, "path")}:${field(resource, "kind")}:rank=${field(resource, "rank")}:type=${field(resource, "typeId")}'];
    var metaSpecs = [for (spec in metadataArray(meta, "templates")) '${field(spec, "path")}:${field(spec, "type")}'];
    var metaCapabilities = [for (capability in metadataArray(meta, "capabilities")) Std.string(capability)];
    metaCapabilities.sort(Reflect.compare);

    return '{'
      + '"version":${field(dump, "version")},'
      + '"sections":${stringArray(sections)},'
      + '"parameters":${stringArray(parameters)},'
      + '"typeTable":${stringArray(types)},'
      + '"argTable":${stringArray(args)},'
      + '"resourceTable":${stringArray(resources)},'
      + '"structTable":${stringArray(structs)},'
      + '"specTable":${stringArray(specs)},'
      + '"metaArgs":${stringArray(metaArgs)},'
      + '"metaResources":${stringArray(metaResources)},'
      + '"metaSpecs":${stringArray(metaSpecs)},'
      + '"metaCapabilities":${stringArray(metaCapabilities)}'
      + '}';
  }

  static function check(test:DescriptorGoldenCase):Void {
    try {
      var got = normalize(test.kernel);
      var expected = StringTools.trim(sys.io.File.getContent(test.path));
      if (got != expected) {
        throw 'descriptor golden mismatch for ${test.path}\nexpected: ${expected}\nactual:   ${got}';
      }
      test.kernel.raw().close();
    } catch (e:Dynamic) {
      try test.kernel.raw().close() catch (_:Dynamic) {}
      throw e;
    }
  }

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static function checkInvalidSchemaVersion(ctx:Context):Void {
    var descriptor = Kernel.descriptorBytes(macro (x:Tensor<I32>) -> {
      x[0] = 1;
    }, {name: "descriptor_invalid_schema_version"});
    var descriptorLength = u32(descriptor, 16);
    descriptor.setUI8(4, 2);
    try {
      var kernel = Kernel.fromDescriptor(ctx, descriptor, descriptorLength);
      kernel.close();
      throw "descriptor_invalid_schema_version unexpectedly compiled";
    } catch (e:Dynamic) {
      var message = Std.string(e);
      if (!StringTools.contains(message, "unsupported version")) {
        throw 'descriptor_invalid_schema_version produced wrong error: ${message}';
      }
    }
  }

  public static function run():Void {
    var ctx:Context = null;
    try {
      ctx = Context.create({arch: Arch.Cpu});
      check({
        path: '${GOLDEN_DIR}/primitive_spec.qdhl.json',
        kernel: Kernel.build(ctx, macro (x:Tensor<I32>, n:Spec<Int>) -> {
          x[0] = n;
        }, {name: "descriptor_golden_primitive_spec"}),
      });
      check({
        path: '${GOLDEN_DIR}/field_resource.qdhl.json',
        kernel: Kernel.build(ctx, macro (field:Field<I32>) -> {
          field[0] = field[0] + 1;
        }, {name: "descriptor_golden_field_resource"}),
      });
      check({
        path: '${GOLDEN_DIR}/struct_tensor.qdhl.json',
        kernel: Kernel.build(ctx, macro (particles:StructTensor<DescriptorGoldenParticle>) -> {
          var particle = particles[0];
          particle.id = particle.id + 1;
          particle.mass = particle.mass + (0.5 : F32);
          particle.pos.x = particle.pos.x + (2.0 : F32);
          particles[0] = particle;
        }, {name: "descriptor_golden_struct_tensor"}),
      });
      checkInvalidSchemaVersion(ctx);
      ctx.close();
    } catch (e:Dynamic) {
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
