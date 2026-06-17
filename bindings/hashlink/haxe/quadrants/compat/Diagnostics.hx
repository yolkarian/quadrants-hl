package quadrants.compat;

import haxe.Json;
import haxe.io.Bytes;
import quadrants.Context;
import quadrants.FieldRuntime;
import quadrants.Kernel;
import quadrants.TensorRuntime;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.coverage.Coverage;

private typedef DescriptorSection = {
  var kind:Int;
  var name:String;
  var offset:Int;
  var length:Int;
}

class Diagnostics {
  public static function descriptorHash(kernel:Kernel):String {
    requireKernel(kernel);
    return kernel.descriptorHash();
  }

  public static function descriptorDump(kernel:Kernel):Dynamic {
    requireKernel(kernel);
    var length = kernel.descriptorLengthBytes();
    if (length < 20) {
      throw "Quadrants descriptor is too short to dump";
    }
    if (readString(kernel, 0, 4) != "QDHL") {
      throw "Quadrants descriptor dump expected QDHL magic";
    }

    var version = readU32(kernel, 4);
    var sectionCount = readU32(kernel, 8);
    var headerSize = readU32(kernel, 12);
    var dataOffset = readU32(kernel, 16);
    if (headerSize < 20 || headerSize + sectionCount * 12 > length) {
      throw "Quadrants descriptor section table is out of bounds";
    }

    var sections:Array<DescriptorSection> = [];
    for (i in 0...sectionCount) {
      var entry = headerSize + i * 12;
      var kind = readU32(kernel, entry);
      var offset = readU32(kernel, entry + 4);
      var sectionLength = readU32(kernel, entry + 8);
      requireRange(kernel, offset, sectionLength, 'descriptor section ${kind}');
      sections.push({kind: kind, name: sectionName(kind), offset: offset, length: sectionLength});
    }

    var strings = parseStrings(kernel, sectionByKind(sections, 1));
    var symbols = parseSymbols(kernel, sectionByKind(sections, 5), strings);
    var attributes = parseAttributes(kernel, sectionByKind(sections, 10));
    return {
      magic: "QDHL",
      version: version,
      descriptorLength: length,
      descriptorHash: kernel.descriptorHash(),
      headerSize: headerSize,
      dataOffset: dataOffset,
      sections: sections,
      stringsCount: strings.length,
      sourceSpans: parseSourceSpans(kernel, sectionByKind(sections, 2), strings),
      parameters: Reflect.field(symbols, "parameters"),
      locals: Reflect.field(symbols, "locals"),
      statements: parseStatements(kernel, sectionByKind(sections, 7), strings),
      attributes: attributes,
      descriptor: Reflect.field(attributes, "qdhl.meta.json") == null ? null : haxe.Json.parse(cast Reflect.field(attributes, "qdhl.meta.json")),
      descriptorV3: Reflect.field(attributes, "qdhl.meta.json") == null ? null : haxe.Json.parse(cast Reflect.field(attributes, "qdhl.meta.json")),
      descriptorV2: Reflect.field(attributes, "qdhl.meta.json") == null ? null : haxe.Json.parse(cast Reflect.field(attributes, "qdhl.meta.json"))
    };
  }

  public static function dumpDescriptor(kernel:Kernel):String {
    return Json.stringify(descriptorDump(kernel));
  }

  public static function kernelInfo(kernel:Kernel):Dynamic {
    requireKernel(kernel);
    return {
      kernelName: kernel.kernelName(),
      descriptorHash: kernel.descriptorHash(),
      descriptorLength: kernel.descriptorLengthBytes(),
      autodiffMode: Coverage.autodiffModeName(kernel.autodiffModeValue()),
      graphLaunchByDefault: kernel.graphLaunchByDefaultEnabled(),
      closed: kernel.isClosed(),
      reverseAutodiffSupported: kernel.reverseAutodiffReason() == null,
      reverseAutodiffBlockedReason: kernel.reverseAutodiffReason()
    };
  }

  public static function valueInfo(value:Dynamic):Dynamic {
    if (value == null) {
      throw "Quadrants Diagnostics.valueInfo requires a value";
    }
    if (Std.isOfType(value, TensorRuntime)) {
      var tensor:TensorRuntime = cast value;
      return {
        kind: "tensor",
        dtype: dtypeName(tensor.dtype),
        shape: copyShape(tensor.shape),
        elementCount: tensor.elementCount(),
        needsGrad: tensor.needsGrad,
        hasGradStorage: tensor.gradTensor != null,
        hasDualStorage: tensor.dualTensor != null,
        contextArch: archName(tensor.context.arch)
      };
    }
    if (Std.isOfType(value, FieldRuntime)) {
      var field:FieldRuntime = cast value;
      return {
        kind: "field",
        dtype: dtypeName(field.dtype),
        shape: copyShape(field.shape),
        placed: field.shape != null,
        closed: field.closed,
        elementCount: field.shape == null || field.closed ? 0 : field.elementCount(),
        hasGradStorage: field.gradField != null,
        hasDualStorage: field.dualField != null,
        ownsTensor: field.ownsTensor,
        snodeId: field.snodeId,
        snodeTreeId: field.snodeTreeId,
        contextArch: archName(field.context.arch)
      };
    }
    throw "Quadrants Diagnostics.valueInfo supports Tensor and Field values";
  }

  public static function health(context:Context):Dynamic {
    if (context == null) {
      throw "Quadrants Diagnostics.health requires a Context";
    }
    var errors:Array<String> = [];
    var nativeOpen = true;
    try {
      context.nativeHandle();
    } catch (e:Dynamic) {
      nativeOpen = false;
      errors.push(Std.string(e));
    }

    var streamEvents:Null<Bool> = null;
    if (nativeOpen) {
      try {
        streamEvents = context.supportsStreamEvents();
      } catch (e:Dynamic) {
        errors.push(Std.string(e));
      }
    }

    return {
      healthy: errors.length == 0,
      arch: archName(context.arch),
      offlineCacheEnabled: context.offlineCacheEnabled,
      offlineCachePath: context.offlineCachePath,
      supportsStreamEvents: streamEvents,
      errors: errors
    };
  }

  public static function assertHealthy(context:Context):Void {
    var result = health(context);
    var healthy:Bool = Reflect.field(result, "healthy");
    if (!healthy) {
      var errors:Array<String> = cast Reflect.field(result, "errors");
      throw "Quadrants runtime health check failed: " + errors.join("; ");
    }
  }

  static function requireKernel(kernel:Kernel):Void {
    if (kernel == null) {
      throw "Quadrants Diagnostics requires a kernel";
    }
  }

  static function sectionByKind(sections:Array<DescriptorSection>, kind:Int):Null<DescriptorSection> {
    for (section in sections) {
      if (section.kind == kind) {
        return section;
      }
    }
    return null;
  }

  static function parseStrings(kernel:Kernel, section:Null<DescriptorSection>):Array<String> {
    var strings:Array<String> = [];
    if (section == null) {
      return strings;
    }
    var pos = section.offset;
    var end = section.offset + section.length;
    var count = readU32(kernel, pos);
    pos += 4;
    for (_ in 0...count) {
      if (pos + 4 > end) {
        throw "Quadrants descriptor strings section is truncated";
      }
      var length = readU32(kernel, pos);
      pos += 4;
      if (pos + length > end) {
        throw "Quadrants descriptor string payload is truncated";
      }
      strings.push(readString(kernel, pos, length));
      pos += length;
    }
    return strings;
  }

  static function parseSourceSpans(kernel:Kernel, section:Null<DescriptorSection>, strings:Array<String>):Array<Dynamic> {
    var spans:Array<Dynamic> = [];
    if (section == null || section.length == 0) {
      return spans;
    }
    var pos = section.offset;
    var end = section.offset + section.length;
    var count = readU32(kernel, pos);
    pos += 4;
    for (_ in 0...count) {
      if (pos + 16 > end) {
        throw "Quadrants descriptor source span section is truncated";
      }
      var fileId = readU32(kernel, pos);
      var line = readU32(kernel, pos + 4);
      var min = readU32(kernel, pos + 8);
      var max = readU32(kernel, pos + 12);
      spans.push({file: stringAt(strings, fileId), line: line, min: min, max: max});
      pos += 16;
    }
    return spans;
  }

  static function parseSymbols(kernel:Kernel, section:Null<DescriptorSection>, strings:Array<String>):Dynamic {
    var parameters:Array<Dynamic> = [];
    var locals:Array<Dynamic> = [];
    if (section == null || section.length == 0) {
      return {parameters: parameters, locals: locals};
    }
    var pos = section.offset;
    var end = section.offset + section.length;
    if (pos + 4 > end) {
      throw "Quadrants descriptor symbols section is truncated";
    }
    var parameterBytes = readU32(kernel, pos);
    pos += 4;
    var parameterEnd = pos + parameterBytes;
    if (parameterEnd > end) {
      throw "Quadrants descriptor parameter block is out of bounds";
    }
    parameters = parseParameters(kernel, pos, parameterEnd, strings);
    pos = parameterEnd;
    if (pos + 4 > end) {
      throw "Quadrants descriptor local block length is missing";
    }
    var localBytes = readU32(kernel, pos);
    pos += 4;
    var localEnd = pos + localBytes;
    if (localEnd > end) {
      throw "Quadrants descriptor local block is out of bounds";
    }
    locals = parseLocals(kernel, pos, localEnd, strings);
    return {parameters: parameters, locals: locals};
  }

  static function parseParameters(kernel:Kernel, offset:Int, end:Int, strings:Array<String>):Array<Dynamic> {
    var parameters:Array<Dynamic> = [];
    if (offset + 4 > end) {
      throw "Quadrants descriptor parameter block is truncated";
    }
    var pos = offset;
    var count = readU32(kernel, pos);
    pos += 4;
    for (_ in 0...count) {
      if (pos + 8 > end) {
        throw "Quadrants descriptor parameter entry is truncated";
      }
      var kind = kernel.descriptorByteAt(pos);
      var dtype = kernel.descriptorByteAt(pos + 1);
      var rank = kernel.descriptorByteAt(pos + 2);
      var needsGrad = kernel.descriptorByteAt(pos + 3) != 0;
      var nameId = readU32(kernel, pos + 4);
      parameters.push({name: stringAt(strings, nameId), kind: parameterKindName(kind), dtype: dtypeNameById(dtype), rank: rank, needsGrad: needsGrad});
      pos += 8;
    }
    return parameters;
  }

  static function parseLocals(kernel:Kernel, offset:Int, end:Int, strings:Array<String>):Array<Dynamic> {
    var locals:Array<Dynamic> = [];
    if (offset + 4 > end) {
      throw "Quadrants descriptor local block is truncated";
    }
    var pos = offset;
    var count = readU32(kernel, pos);
    pos += 4;
    for (_ in 0...count) {
      if (pos + 12 > end) {
        throw "Quadrants descriptor local entry is truncated";
      }
      var dtype = kernel.descriptorByteAt(pos);
      var allocate = kernel.descriptorByteAt(pos + 1) != 0;
      var nameId = readU32(kernel, pos + 4);
      var sharedSize = readU32(kernel, pos + 8);
      locals.push({name: stringAt(strings, nameId), dtype: dtypeNameById(dtype), allocate: allocate, sharedSize: sharedSize});
      pos += 12;
    }
    return locals;
  }

  static function parseStatements(kernel:Kernel, section:Null<DescriptorSection>, strings:Array<String>):Dynamic {
    if (section == null || section.length < 8) {
      return null;
    }
    var kernelNameId = readU32(kernel, section.offset);
    var statementCount = readU32(kernel, section.offset + 4);
    return {kernelName: stringAt(strings, kernelNameId), statementCount: statementCount};
  }

  static function parseAttributes(kernel:Kernel, section:Null<DescriptorSection>):Dynamic {
    var result:Dynamic = {};
    if (section == null || section.length < 4) {
      return result;
    }
    var pos = section.offset;
    var end = section.offset + section.length;
    var count = readU32(kernel, pos);
    pos += 4;
    for (_ in 0...count) {
      if (pos + 4 > end) {
        throw "Quadrants descriptor attribute key length is truncated";
      }
      var keyLength = readU32(kernel, pos);
      pos += 4;
      var key = readString(kernel, pos, keyLength);
      pos += keyLength;
      if (pos + 4 > end) {
        throw "Quadrants descriptor attribute value length is truncated";
      }
      var valueLength = readU32(kernel, pos);
      pos += 4;
      var value = readString(kernel, pos, valueLength);
      pos += valueLength;
      Reflect.setField(result, key, value);
    }
    return result;
  }

  static function readU32(kernel:Kernel, offset:Int):Int {
    requireRange(kernel, offset, 4, "u32");
    return kernel.descriptorByteAt(offset)
      | (kernel.descriptorByteAt(offset + 1) << 8)
      | (kernel.descriptorByteAt(offset + 2) << 16)
      | (kernel.descriptorByteAt(offset + 3) << 24);
  }

  static function readString(kernel:Kernel, offset:Int, length:Int):String {
    requireRange(kernel, offset, length, "string");
    var bytes = Bytes.alloc(length);
    for (i in 0...length) {
      bytes.set(i, kernel.descriptorByteAt(offset + i));
    }
    return bytes.getString(0, length);
  }

  static function requireRange(kernel:Kernel, offset:Int, length:Int, label:String):Void {
    if (offset < 0 || length < 0 || offset + length > kernel.descriptorLengthBytes()) {
      throw 'Quadrants descriptor ${label} range is out of bounds';
    }
  }

  static function stringAt(strings:Array<String>, id:Int):Null<String> {
    return id >= 0 && id < strings.length ? strings[id] : null;
  }

  static function copyShape(shape:Array<Int>):Dynamic {
    return shape == null ? null : [for (value in shape) value];
  }

  static function archName(arch:Arch):String {
    return switch (arch) {
      case Arch.Cpu: "cpu";
      case Arch.Cuda: "cuda";
      case Arch.Vulkan: "vulkan";
      case Arch.Metal: "metal";
      case Arch.Amdgpu: "amdgpu";
    };
  }

  static function dtypeName(dtype:DType):String {
    return switch (dtype) {
      case DType.I8: "i8";
      case DType.I16: "i16";
      case DType.I32: "i32";
      case DType.I64: "i64";
      case DType.U8: "u8";
      case DType.U16: "u16";
      case DType.U32: "u32";
      case DType.U64: "u64";
      case DType.F32: "f32";
      case DType.F64: "f64";
      case DType.U1: "u1";
      case DType.F16: "f16";
    };
  }

  static function dtypeNameById(dtype:Int):String {
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

  static function parameterKindName(kind:Int):String {
    return switch (kind) {
      case 0: "scalar";
      case 1: "ndarray";
      default: 'unknown(${kind})';
    };
  }

  static function sectionName(kind:Int):String {
    return switch (kind) {
      case 1: "strings";
      case 2: "sourceSpans";
      case 3: "types";
      case 4: "constants";
      case 5: "symbols";
      case 6: "expressions";
      case 7: "statements";
      case 8: "functions";
      case 9: "kernels";
      case 10: "attributes";
      default: 'unknown(${kind})';
    };
  }
}
