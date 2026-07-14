package quadrants.macro;

#if macro
import haxe.io.Bytes as HxBytes;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.PositionTools;
import haxe.macro.Type;
import haxe.macro.TypeTools;

import sys.io.File;
private typedef ParamInfo = {
  var name:String;
  var kind:Int;
  var rank:Int;
  var dtype:Int;
  var needsGrad:Bool;
  var rankFromShape:Bool;
  var spec:Bool;
}

private typedef LocalInfo = {
  var name:String;
  var allocate:Bool;
  var dtype:Int;
  var sharedSize:Int;
}

private typedef VectorLocalInfo = {
  var localIds:Array<Int>;
  var dtype:Int;
}

private typedef VectorInitInfo = {
  var values:Array<Expr>;
  var dtype:Int;
}


private typedef MatrixLocalInfo = {
  var localIds:Array<Int>;
  var rows:Int;
  var cols:Int;
  var dtype:Int;
}

private typedef MatrixInitInfo = {
  var values:Array<Expr>;
  var rows:Int;
  var cols:Int;
  var dtype:Int;
}
private typedef StructFieldInfo = {
  var localId:Int;
  var dtype:Int;
}

private typedef StructLocalInfo = {
  var fields:Map<String, StructFieldInfo>;
  var order:Array<String>;
}

private typedef StructResourceMemberInfo = {
  var name:String;
  var paramId:Int;
  var dtype:Int;
  var lanes:Int;
  var laneIndex:Int;
  var offset:Int;
  var align:Int;
  var size:Int;
}

private typedef StructResourceInfo = {
  var name:String;
  var structName:String;
  var kind:Int;
  var sizeBytes:Int;
  var alignBytes:Int;
  var members:Map<String, StructResourceMemberInfo>;
  var order:Array<String>;
}


private typedef MeshForInfo = {
  var elementType:Int;
  var counts:Array<Int>;
}

private typedef NdrangeForInfo = {
  var begins:Array<Expr>;
  var ends:Array<Expr>;
  var axes:Array<Int>;
}
private typedef QdFunctionInfo = {
  var name:String;
  var owner:String;
  var args:Array<FunctionArg>;
  var body:Expr;
  var ret:Null<ComplexType>;
  var pos:Position;
}


private class ByteWriter {
  public final bytes:Array<Int> = [];

  public function new() {}

  public function u8(value:Int):Void {
    bytes.push(value & 0xff);
  }

  public function u32(value:Int):Void {
    bytes.push(value & 0xff);
    bytes.push((value >>> 8) & 0xff);
    bytes.push((value >>> 16) & 0xff);
    bytes.push((value >>> 24) & 0xff);
  }

  public function i32(value:Int):Void {
    u32(value);
  }

  public function u64Parts(low:Int, high:Int):Void {
    u32(low);
    u32(high);
  }

  public function i64Parts(low:Int, high:Int):Void {
    u64Parts(low, high);
  }

  public function f32(value:Float):Void {
    var encoded = HxBytes.alloc(4);
    encoded.setFloat(0, value);
    for (i in 0...4) {
      u8(encoded.get(i));
    }
  }

  public function f64(value:Float):Void {
    var encoded = HxBytes.alloc(8);
    encoded.setDouble(0, value);
    for (i in 0...8) {
      u8(encoded.get(i));
    }
  }

  public function append(other:Array<Int>):Void {
    for (value in other) {
      bytes.push(value);
    }
  }

  public function string(value:String):Void {
    var encoded = HxBytes.ofString(value);
    u32(encoded.length);
    for (i in 0...encoded.length) {
      u8(encoded.get(i));
    }
  }
}

private class DescriptorBuilder {
  static inline var PARAM_UNKNOWN = -1;
  static inline var PARAM_SCALAR = 0;
  static inline var PARAM_NDARRAY = 1;
  static inline var PARAM_FIELD = 2;
  static inline var PARAM_MESH_RELATION = 3;
  static inline var PARAM_MESH_ATTRIBUTE = 4;
  static inline var DTYPE_I8 = 0;
  static inline var DTYPE_I16 = 1;
  static inline var DTYPE_I32 = 2;
  static inline var DTYPE_I64 = 3;
  static inline var DTYPE_U8 = 4;
  static inline var DTYPE_U16 = 5;
  static inline var DTYPE_U32 = 6;
  static inline var DTYPE_U64 = 7;
  static inline var DTYPE_F32 = 8;
  static inline var DTYPE_F64 = 9;
  static inline var DTYPE_U1 = 10;
  static inline var DTYPE_F16 = 11;

  static inline var EXPR_CONST_I32 = 1;
  static inline var EXPR_ARG_LOAD = 2;
  static inline var EXPR_LOCAL_LOAD = 3;
  static inline var EXPR_LOAD_INDEX = 4;
  static inline var EXPR_BINARY_ADD = 5;
  static inline var EXPR_BINARY_SUB = 6;
  static inline var EXPR_BINARY_MUL = 7;
  static inline var EXPR_BINARY_DIV = 8;
  static inline var EXPR_BINARY_MOD = 9;
  static inline var EXPR_CMP_EQ = 10;
  static inline var EXPR_CMP_NE = 11;
  static inline var EXPR_CMP_LT = 12;
  static inline var EXPR_CMP_LE = 13;
  static inline var EXPR_CMP_GT = 14;
  static inline var EXPR_CMP_GE = 15;
  static inline var EXPR_LOGIC_AND = 16;
  static inline var EXPR_LOGIC_OR = 17;
  static inline var EXPR_LOGIC_NOT = 18;
  static inline var EXPR_BIT_AND = 19;
  static inline var EXPR_BIT_OR = 20;
  static inline var EXPR_BIT_XOR = 21;
  static inline var EXPR_SHL = 22;
  static inline var EXPR_SHR = 23;
  static inline var EXPR_SAR = 24;
  static inline var EXPR_CAST = 25;
  static inline var EXPR_UNARY_ABS = 26;
  static inline var EXPR_SIN = 27;
  static inline var EXPR_COS = 28;
  static inline var EXPR_TAN = 29;
  static inline var EXPR_EXP = 30;
  static inline var EXPR_LOG = 31;
  static inline var EXPR_SQRT = 32;
  static inline var EXPR_FLOOR = 33;
  static inline var EXPR_CEIL = 34;
  static inline var EXPR_MIN = 35;
  static inline var EXPR_MAX = 36;
  static inline var EXPR_SELECT = 37;
  static inline var EXPR_UNARY_NEG = 38;
  static inline var EXPR_BIT_NOT = 39;
  static inline var EXPR_CONST_F64 = 40;
  static inline var EXPR_ATOMIC_ADD = 41;
  static inline var EXPR_CONST_I64 = 42;
  static inline var EXPR_CONST_U64 = 43;
  static inline var EXPR_CONST_F32 = 44;
  static inline var EXPR_CONST_BOOL = 45;
  static inline var EXPR_ASIN = 46;
  static inline var EXPR_ACOS = 47;
  static inline var EXPR_ATAN2 = 48;
  static inline var EXPR_POW = 49;
  static inline var EXPR_RSQRT = 50;
  static inline var EXPR_ROUND = 51;
  static inline var EXPR_ATOMIC_SUB = 52;
  static inline var EXPR_ATOMIC_MIN = 53;
  static inline var EXPR_ATOMIC_MAX = 54;
  static inline var EXPR_ATOMIC_AND = 55;
  static inline var EXPR_ATOMIC_OR = 56;
  static inline var EXPR_ATOMIC_XOR = 57;
  static inline var EXPR_ATOMIC_EXCHANGE = 58;
  static inline var EXPR_THREAD_IDX = 59;
  static inline var EXPR_SHAPE_AXIS = 60;
  static inline var EXPR_TANH = 61;
  static inline var EXPR_INV = 62;
  static inline var EXPR_RCP = 63;
  static inline var EXPR_POPCNT = 64;
  static inline var EXPR_CLZ = 65;
  static inline var EXPR_FFS = 66;
  static inline var EXPR_SGN = 67;
  static inline var EXPR_BIT_CAST = 68;
  static inline var EXPR_ATOMIC_MUL = 69;
  static inline var EXPR_BLOCK_THREAD_IDX = 70;
  static inline var EXPR_SUBGROUP_SIZE = 71;
  static inline var EXPR_SUBGROUP_INVOCATION_ID = 72;
  static inline var EXPR_SUBGROUP_ELECT = 73;
  static inline var EXPR_SUBGROUP_SHUFFLE = 74;
  static inline var EXPR_SUBGROUP_SHUFFLE_DOWN = 75;
  static inline var EXPR_SUBGROUP_SHUFFLE_UP = 76;
  static inline var EXPR_SUBGROUP_BROADCAST = 77;
  static inline var EXPR_LOCAL_INVOCATION_ID = 78;
  static inline var EXPR_GLOBAL_INVOCATION_ID = 79;
  static inline var EXPR_VK_GLOBAL_THREAD_IDX = 80;
  static inline var EXPR_CUDA_ACTIVE_MASK = 81;
  static inline var EXPR_BLOCK_BARRIER_AND = 82;
  static inline var EXPR_BLOCK_BARRIER_OR = 83;
  static inline var EXPR_BLOCK_BARRIER_COUNT = 84;
  static inline var EXPR_ATOMIC_COMPARE_EXCHANGE = 85;
  static inline var EXPR_RAND = 86;
  static inline var EXPR_ASSUME_IN_RANGE = 87;
  static inline var EXPR_VOLATILE_LOAD_INDEX = 88;
  static inline var EXPR_FREXP_SIGNIFICAND = 89;
  static inline var EXPR_FREXP_EXPONENT = 90;
  static inline var EXPR_FNS_U32 = 91;
  static inline var EXPR_SNODE_APPEND = 92;
  static inline var EXPR_SNODE_LENGTH = 93;
  static inline var EXPR_SNODE_IS_ACTIVE = 94;
  static inline var EXPR_MESH_RELATION_SIZE = 95;
  static inline var EXPR_MESH_RELATION_GET = 96;
  static inline var EXPR_MESH_INDEX_CONVERT = 97;
  static inline var EXPR_CLOCK_I64 = 98;
  static inline var EXPR_CUDA_MATCH_ANY = 99;
  static inline var EXPR_CUDA_MATCH_ALL = 100;
  static inline var EXPR_SUBGROUP_BALLOT_U64 = 101;
  static inline var STMT_LOCAL_ALLOC = 1;
  static inline var STMT_STORE_INDEX = 2;
  static inline var STMT_RANGE_FOR = 3;
  static inline var STMT_IF = 4;
  static inline var STMT_ASSIGN = 5;
  static inline var STMT_RETURN_VOID = 6;
  static inline var STMT_WHILE = 7;
  static inline var STMT_BREAK = 8;
  static inline var STMT_CONTINUE = 9;
  static inline var STMT_ATOMIC_ADD = 10;
  static inline var STMT_ATOMIC_SUB = 11;
  static inline var STMT_RETURN_VALUE = 12;
  static inline var STMT_ATOMIC_MIN = 13;
  static inline var STMT_ATOMIC_MAX = 14;
  static inline var STMT_ATOMIC_AND = 15;
  static inline var STMT_ATOMIC_OR = 16;
  static inline var STMT_ATOMIC_XOR = 17;
  static inline var STMT_ATOMIC_EXCHANGE = 18;
  static inline var STMT_ATOMIC_MUL = 19;
  static inline var STMT_BLOCK_DIM = 20;
  static inline var STMT_PARALLELIZE = 21;
  static inline var STMT_SERIALIZE = 22;
  static inline var STMT_PRINT = 23;
  static inline var STMT_ASSERT = 24;
  static inline var STMT_BLOCK_BARRIER = 25;
  static inline var STMT_BLOCK_MEM_FENCE = 26;
  static inline var STMT_GRID_MEM_FENCE = 27;
  static inline var STMT_WORKGROUP_BARRIER = 28;
  static inline var STMT_WORKGROUP_MEMORY_BARRIER = 29;
  static inline var STMT_GRID_MEMORY_BARRIER = 30;
  static inline var STMT_SUBGROUP_BARRIER = 31;
  static inline var STMT_SUBGROUP_MEMORY_BARRIER = 32;
  static inline var STMT_WARP_BARRIER = 33;
  static inline var STMT_STRUCT_FOR_EXTERNAL_TENSOR = 34;
  static inline var STMT_RETURN_VALUES = 35;
  static inline var STMT_MESH_FOR = 36;
  static inline var STMT_SNODE_ACTIVATE = 37;
  static inline var STMT_SNODE_DEACTIVATE = 38;
  static inline var STMT_STRUCT_FOR_FIELD = 39;
  static inline var STMT_STOP_GRAD = 40;
  static inline var STMT_PRINT_ENTRIES = 41;

  final params:Array<ParamInfo> = [];
  final paramIds:Map<String, Int> = new Map();
  final bufferViewStartParamIds:Map<String, Int> = new Map();
  final bufferViewLengthParamIds:Map<String, Int> = new Map();
  final meshRelationSizeParamIds:Map<String, Int> = new Map();
  final meshAttributeParamIds:Map<String, Bool> = new Map();
  final quantScaleParamIds:Map<String, Int> = new Map();
  final quantMinParamIds:Map<String, Int> = new Map();
  final quantMaxParamIds:Map<String, Int> = new Map();
  final locals:Array<LocalInfo> = [];
  final scopes:Array<Map<String, Int>> = [];
  final indexVectorScopes:Array<Map<String, Array<Int>>> = [];
  final vectorScopes:Array<Map<String, VectorLocalInfo>> = [];
  final matrixScopes:Array<Map<String, MatrixLocalInfo>> = [];
  final structScopes:Array<Map<String, StructLocalInfo>> = [];
  final structResources:Map<String, StructResourceInfo> = new Map();
  final functions:Map<String, QdFunctionInfo>;
  final kernelName:String;
  final descriptorMetadataJson:Null<String>;
  final inlineArgScopes:Array<Map<String, Expr>> = [];
  final inlineFunctionStack:Array<String> = [];
  final inlineReturnTargets:Array<Int> = [];
  var loopDepth:Int = 0;
  var hasReturn:Bool = false;
  var returnDType:Int = DTYPE_I32;
  var returnDTypes:Array<Int> = [];
  static inline var STATIC_UNROLL_LIMIT = 1024;
  final clampBoundaryParams = new Map<String, Bool>();
  var switchTempCounter:Int = 0;
  var swizzleTempCounter:Int = 0;
  public function new(args:Array<FunctionArg>, functions:Map<String, QdFunctionInfo>, kernelName:String, ?descriptorMetadataJson:String) {
    for (arg in args) {
      if (paramIds.exists(arg.name) || structResources.exists(arg.name)) {
        Context.error('Duplicate Quadrants kernel parameter ${arg.name}', arg.value == null ? Context.currentPos() : arg.value.pos);
      }
      var argPos = arg.value == null ? Context.currentPos() : arg.value.pos;
      var structInfo = structResourceInfo(arg.name, arg.type, argPos);
      if (structInfo != null) {
        structResources[arg.name] = structInfo;
      } else if (isMeshRelationComplexType(arg.type)) {
        paramIds[arg.name] = params.length;
        params.push({name: arg.name, kind: PARAM_MESH_RELATION, rank: 0, dtype: DTYPE_I32, needsGrad: false, rankFromShape: false, spec: false});
        meshRelationSizeParamIds[arg.name] = paramIds[arg.name];
      } else if (isQuantizedF32TensorComplexType(arg.type)) {
        paramIds[arg.name] = params.length;
        params.push({name: arg.name, kind: PARAM_NDARRAY, rank: 1, dtype: DTYPE_I32, needsGrad: false, rankFromShape: false, spec: false});
        var scaleParamId = params.length;
        params.push({name: uniqueParameterName('__qd_quant_scale_${arg.name}'), kind: PARAM_SCALAR, rank: 0, dtype: DTYPE_F32, needsGrad: false, rankFromShape: false, spec: false});
        var minParamId = params.length;
        params.push({name: uniqueParameterName('__qd_quant_min_${arg.name}'), kind: PARAM_SCALAR, rank: 0, dtype: DTYPE_I32, needsGrad: false, rankFromShape: false, spec: false});
        var maxParamId = params.length;
        params.push({name: uniqueParameterName('__qd_quant_max_${arg.name}'), kind: PARAM_SCALAR, rank: 0, dtype: DTYPE_I32, needsGrad: false, rankFromShape: false, spec: false});
        quantScaleParamIds[arg.name] = scaleParamId;
        quantMinParamIds[arg.name] = minParamId;
        quantMaxParamIds[arg.name] = maxParamId;
      } else if (isBufferViewComplexType(arg.type)) {
        var dtype = bufferViewElementDType(arg.type, argPos);
        paramIds[arg.name] = params.length;
        params.push({name: arg.name, kind: PARAM_NDARRAY, rank: 1, dtype: dtype, needsGrad: needsGradForDType(dtype), rankFromShape: false, spec: false});
        var startParamId = params.length;
        params.push({name: uniqueParameterName('__qd_view_start_${arg.name}'), kind: PARAM_SCALAR, rank: 0, dtype: DTYPE_I32, needsGrad: false, rankFromShape: false, spec: false});
        var lengthParamId = params.length;
        params.push({name: uniqueParameterName('__qd_view_length_${arg.name}'), kind: PARAM_SCALAR, rank: 0, dtype: DTYPE_I32, needsGrad: false, rankFromShape: false, spec: false});
        bufferViewStartParamIds[arg.name] = startParamId;
        bufferViewLengthParamIds[arg.name] = lengthParamId;
      } else {
        var typeInfo = parameterTypeInfo(arg.type, argPos);
        paramIds[arg.name] = params.length;
        params.push({name: arg.name, kind: typeInfo.kind, rank: 0, dtype: typeInfo.dtype, needsGrad: typeInfo.needsGrad, rankFromShape: false, spec: typeInfo.spec});
        if (isMeshAttributeComplexType(arg.type)) {
          params[params.length - 1].kind = PARAM_MESH_ATTRIBUTE;
          params[params.length - 1].rank = 1;
          meshAttributeParamIds[arg.name] = true;
        }
      }
      applyBoundaryMeta(arg, argPos);
    }
    this.functions = functions;
    this.kernelName = kernelName;
    this.descriptorMetadataJson = descriptorMetadataJson;
    scopes.push(new Map());
    vectorScopes.push(new Map());
    matrixScopes.push(new Map());
    structScopes.push(new Map());
  }

  function applyBoundaryMeta(arg:FunctionArg, argPos:Position):Void {
    if (arg.meta == null) {
      return;
    }
    for (entry in arg.meta) {
      if (entry.name != ":qdBoundary" && entry.name != "qdBoundary") {
        continue;
      }
      if (entry.params == null || entry.params.length != 1) {
        Context.error("Quadrants @:qdBoundary expects one boundary mode string", entry.pos);
      }
      var mode = switch (stripNoCasts(entry.params[0]).expr) {
        case EConst(CString(value, _)): value;
        default: Context.error("Quadrants @:qdBoundary expects one boundary mode string", entry.params[0].pos);
      };
      if (mode != "clamp") {
        Context.error("Quadrants @:qdBoundary supports only \"clamp\"", entry.params[0].pos);
      }
      registerClampBoundary(arg.name, argPos);
    }
  }

  public function registerClampBoundary(name:String, pos:Position):Void {
    var paramId = paramIds.get(name);
    var supported = paramId != null
      && !bufferViewStartParamIds.exists(name)
      && !meshAttributeParamIds.exists(name)
      && !meshRelationSizeParamIds.exists(name)
      && !quantScaleParamIds.exists(name)
      && params[paramId].kind == PARAM_NDARRAY;
    if (!supported) {
      Context.error('Quadrants boundaryClamp requires a Tensor kernel parameter; ${name} does not qualify', pos);
    }
    clampBoundaryParams[name] = true;
  }

  public function build(functionBody:Expr):Array<Int> {
    var statementBytes = new ByteWriter();
    var statementCount = encodeStatementList(rootStatementsOf(functionBody), statementBytes);
    for (param in params) {
      if (param.kind == PARAM_UNKNOWN) {
        param.kind = PARAM_SCALAR;
      }
    }

    var strings:Array<String> = [];
    var stringIds:Map<String, Int> = new Map();
    function intern(value:String):Int {
      var existing = stringIds.get(value);
      if (existing != null) {
        return existing;
      }
      var id = strings.length;
      strings.push(value);
      stringIds[value] = id;
      return id;
    }

    var kernelNameId = intern(kernelName);
    for (param in params) {
      intern(param.name);
    }
    for (local in locals) {
      intern(local.name);
    }

    var functionPos = PositionTools.getInfos(functionBody.pos);
    var functionSourceLine = sourceLine(functionPos.file, functionPos.min);
    var functionSourceFileId = intern(functionPos.file);
    var functionNames = [for (name in functions.keys()) name];
    for (name in functionNames) {
      intern(name);
      var info = functions.get(name);
      for (arg in info.args) {
        intern(arg.name);
      }
    }
    for (resourceName in structResources.keys()) {
      var structInfo = structResources.get(resourceName);
      intern(structInfo.structName);
      for (fieldName in structInfo.order) {
        intern(fieldName);
      }
    }

    var stringsSection = new ByteWriter();
    stringsSection.u32(strings.length);
    for (value in strings) {
      stringsSection.string(value);
    }

    var paramsSection = new ByteWriter();
    paramsSection.u32(params.length);
    for (param in params) {
      paramsSection.u8(param.kind);
      paramsSection.u8(param.dtype);
      paramsSection.u8(param.rank);
      paramsSection.u8((param.needsGrad ? 1 : 0) | (param.spec ? 2 : 0));
      paramsSection.u32(intern(param.name));
    }

    var localsSection = new ByteWriter();
    localsSection.u32(locals.length);
    for (local in locals) {
      localsSection.u8(local.dtype);
      localsSection.u8(local.allocate ? 1 : 0);
      localsSection.u8(0);
      localsSection.u8(0);
      localsSection.u32(intern(local.name));
      localsSection.u32(local.sharedSize);
    }

    var sourceSpansSection = new ByteWriter();
    sourceSpansSection.u32(1);
    sourceSpansSection.u32(functionSourceFileId);
    sourceSpansSection.u32(functionSourceLine);
    sourceSpansSection.u32(functionPos.min);
    sourceSpansSection.u32(functionPos.max);

    var typesSection = new ByteWriter();
    typesSection.u32(12);
    for (dtype in [DTYPE_I8, DTYPE_I16, DTYPE_I32, DTYPE_I64, DTYPE_U8, DTYPE_U16, DTYPE_U32, DTYPE_U64, DTYPE_F16, DTYPE_F32, DTYPE_F64, DTYPE_U1]) {
      typesSection.u8(dtype);
    }

    var constantsSection = new ByteWriter();
    constantsSection.u32(0);

    function canonicalTypeKind(param:ParamInfo):Int {
      if (param.spec) {
        return 1;
      }
      return switch (param.kind) {
        case PARAM_SCALAR: 0;
        case PARAM_NDARRAY: 2;
        case PARAM_FIELD: 3;
        case PARAM_MESH_RELATION: 6;
        case PARAM_MESH_ATTRIBUTE: 7;
        default: 0;
      };
    }

    var typeEntries:Array<{id:Int, kind:Int, dtype:Int, rank:Int, flags:Int, structId:Int}> = [];
    var paramTypeIds:Array<Int> = [];
    var typeKeys:Map<String, Int> = new Map();
    function ensureCanonicalType(kind:Int, dtype:Int, rank:Int, flags:Int, structId:Int):Int {
      var key = kind + ":" + dtype + ":" + rank + ":" + flags + ":" + structId;
      var typeId = typeKeys.get(key);
      if (typeId == null) {
        typeId = typeEntries.length + 1;
        typeKeys[key] = typeId;
        typeEntries.push({id: typeId, kind: kind, dtype: dtype, rank: rank, flags: flags, structId: structId});
      }
      return typeId;
    }
    for (param in params) {
      var kind = canonicalTypeKind(param);
      var flags = param.needsGrad ? 1 : 0;
      paramTypeIds.push(ensureCanonicalType(kind, param.dtype, param.rank, flags, 0));
    }

    var structEntries = [for (name in structResources.keys()) structResources.get(name)];
    structEntries.sort((a, b) -> Reflect.compare(a.name, b.name));
    var structIds:Map<String, Int> = new Map();
    for (i in 0...structEntries.length) {
      structIds[structEntries[i].structName] = i + 1;
    }
    for (structInfo in structEntries) {
      for (fieldName in structInfo.order) {
        var member = structInfo.members.get(fieldName);
        ensureCanonicalType(0, member.dtype, 0, 0, 0);
      }
    }

    var canonicalTypesSection = new ByteWriter();
    canonicalTypesSection.u32(typeEntries.length);
    for (entry in typeEntries) {
      canonicalTypesSection.u32(entry.id);
      canonicalTypesSection.u8(entry.kind);
      canonicalTypesSection.u8(entry.dtype);
      canonicalTypesSection.u8(entry.rank);
      canonicalTypesSection.u8(entry.flags);
      canonicalTypesSection.u32(entry.structId);
      canonicalTypesSection.u32(0);
    }

    var argTableSection = new ByteWriter();
    argTableSection.u32(params.length);
    for (index in 0...params.length) {
      var param = params[index];
      argTableSection.u32(index);
      argTableSection.u32(paramTypeIds[index]);
      argTableSection.u32(intern(param.name));
      argTableSection.u8(param.spec ? 2 : (param.kind == PARAM_SCALAR ? 0 : 1));
      argTableSection.u8((param.needsGrad ? 1 : 0) | (param.spec ? 2 : 0));
      argTableSection.u8(0);
      argTableSection.u8(0);
    }

    var resourceTableSection = new ByteWriter();
    var resourceCount = 0;
    for (param in params) if (param.kind == PARAM_NDARRAY || param.kind == PARAM_FIELD || param.kind == PARAM_MESH_RELATION || param.kind == PARAM_MESH_ATTRIBUTE) resourceCount++;
    resourceTableSection.u32(resourceCount);
    for (index in 0...params.length) {
      var param = params[index];
      if (param.kind != PARAM_NDARRAY && param.kind != PARAM_FIELD && param.kind != PARAM_MESH_RELATION && param.kind != PARAM_MESH_ATTRIBUTE) {
        continue;
      }
      resourceTableSection.u32(index);
      resourceTableSection.u32(paramTypeIds[index]);
      resourceTableSection.u32(intern(param.name));
      resourceTableSection.u8(canonicalTypeKind(param));
      resourceTableSection.u8(param.rank);
      resourceTableSection.u8(param.needsGrad ? 1 : 0);
      resourceTableSection.u8(0);
    }

    var structTableSection = new ByteWriter();
    structTableSection.u32(structEntries.length);
    for (structInfo in structEntries) {
      structTableSection.u32(structIds.get(structInfo.structName));
      structTableSection.u32(intern(structInfo.structName));
      structTableSection.u32(structInfo.sizeBytes);
      structTableSection.u32(structInfo.alignBytes);
      structTableSection.u32(structInfo.order.length);
      for (fieldName in structInfo.order) {
        var member = structInfo.members.get(fieldName);
        structTableSection.u32(intern(fieldName));
        structTableSection.u32(ensureCanonicalType(0, member.dtype, 0, 0, 0));
        structTableSection.u32(member.offset);
      }
    }

    var specTableSection = new ByteWriter();
    var specCount = 0;
    for (param in params) if (param.spec) specCount++;
    specTableSection.u32(specCount);
    for (index in 0...params.length) {
      var param = params[index];
      if (!param.spec) {
        continue;
      }
      specTableSection.u32(index);
      specTableSection.u32(paramTypeIds[index]);
      specTableSection.u32(intern(param.name));
      specTableSection.u8(param.dtype);
      specTableSection.u8(0);
      specTableSection.u8(0);
      specTableSection.u8(0);
    }

    var symbolsSection = new ByteWriter();
    symbolsSection.u32(paramsSection.bytes.length);
    symbolsSection.append(paramsSection.bytes);
    symbolsSection.u32(localsSection.bytes.length);
    symbolsSection.append(localsSection.bytes);

    var expressionsSection = new ByteWriter();
    expressionsSection.u32(0);

    var statementsSection = new ByteWriter();
    statementsSection.u32(kernelNameId);
    statementsSection.u32(statementCount);
    statementsSection.append(statementBytes.bytes);
    statementsSection.u8(hasReturn ? 1 : 0);
    statementsSection.u8(returnDType);
    statementsSection.u32(hasReturn ? returnDTypes.length : 0);
    if (hasReturn) {
      for (dtype in returnDTypes) {
        statementsSection.u8(dtype);
      }
    }

    var functionsSection = new ByteWriter();
    functionsSection.u32(functionNames.length);
    for (name in functionNames) {
      var info = functions.get(name);
      functionsSection.u32(intern(name));
      functionsSection.u8(1);
      functionsSection.u8(qdFunctionMetadataReturnDType(info));
      functionsSection.u8(0);
      functionsSection.u8(0);
      functionsSection.u32(info.args.length);
      for (arg in info.args) {
        var typeInfo = qdFunctionMetadataArgTypeInfo(arg.type, arg.value == null ? info.pos : arg.value.pos);
        functionsSection.u8(typeInfo.kind == PARAM_UNKNOWN ? PARAM_SCALAR : typeInfo.kind);
        functionsSection.u8(typeInfo.dtype);
        functionsSection.u8(0);
        functionsSection.u8(0);
        functionsSection.u32(intern(arg.name));
      }
    }

    var kernelsSection = new ByteWriter();
    kernelsSection.u32(1);
    kernelsSection.u32(kernelNameId);

    var metadataJson = descriptorMetadataJson;
    if (metadataJson == null) {
      metadataJson = quadrants.macro.DescriptorWriter.autoMetadata(kernelName, [
        for (param in params)
          {
            path: param.name,
            role: param.spec ? "spec" : "runtime",
            kind: param.kind,
            dtype: param.dtype,
            rank: param.rank,
          }
      ]);
    }
    var attributesSection = new ByteWriter();
    attributesSection.append(quadrants.macro.DescriptorWriter.attributesSection(metadataJson));

    var sections = [
      {kind: 1, bytes: stringsSection.bytes},
      {kind: 2, bytes: sourceSpansSection.bytes},
      {kind: 3, bytes: typesSection.bytes},
      {kind: 4, bytes: constantsSection.bytes},
      {kind: 5, bytes: symbolsSection.bytes},
      {kind: 6, bytes: expressionsSection.bytes},
      {kind: 7, bytes: statementsSection.bytes},
      {kind: 8, bytes: functionsSection.bytes},
      {kind: 9, bytes: kernelsSection.bytes},
      {kind: 10, bytes: attributesSection.bytes},
      {kind: 11, bytes: canonicalTypesSection.bytes},
      {kind: 12, bytes: resourceTableSection.bytes},
      {kind: 13, bytes: structTableSection.bytes},
      {kind: 14, bytes: specTableSection.bytes},
      {kind: 15, bytes: argTableSection.bytes},
    ];

    var headerSize = 20;
    var sectionTableSize = sections.length * 12;
    var offset = headerSize + sectionTableSize;
    var offsets = [];
    for (section in sections) {
      offsets.push(offset);
      offset += section.bytes.length;
    }

    var descriptor = new ByteWriter();
    descriptor.u8(0x51);
    descriptor.u8(0x44);
    descriptor.u8(0x48);
    descriptor.u8(0x4c);
    descriptor.u32(quadrants.macro.DescriptorWriter.SCHEMA_VERSION);
    descriptor.u32(sections.length);
    descriptor.u32(headerSize);
    descriptor.u32(offset);
    for (i in 0...sections.length) {
      descriptor.u32(sections[i].kind);
      descriptor.u32(offsets[i]);
      descriptor.u32(sections[i].bytes.length);
    }
    for (section in sections) {
      descriptor.append(section.bytes);
    }
    return descriptor.bytes;
  }

  public function encodedReturnDType():Int {
    return hasReturn ? returnDType : -1;
  }

  function encodeStatement(statement:Expr, writer:ByteWriter):Int {
    var expr = strip(statement);
    switch (expr.expr) {
      case EBlock(expressions):
        pushScope();
        var count = encodeStatementList(expressions, writer);
        popScope();
        return count;
      case EFor(iterator, body):
        return encodeRangeFor(iterator, body, writer, expr.pos);
      case EWhile(condition, body, true):
        encodeWhile(condition, body, writer);
      case EWhile(_, _, false):
        Context.error("Quadrants HashLink does not support do-while loops", expr.pos);
      case EBreak:
        if (loopDepth <= 0) {
          Context.error("Quadrants HashLink break must be inside a loop", expr.pos);
        }
        writer.u8(STMT_BREAK);
      case EContinue:
        if (loopDepth <= 0) {
          Context.error("Quadrants HashLink continue must be inside a loop", expr.pos);
        }
        writer.u8(STMT_CONTINUE);
      case EUnop(OpIncrement, _, target):
        return encodeCompoundAssignment(OpAdd, target, {expr: EConst(CInt("1", null)), pos: expr.pos}, writer, expr.pos);
      case EUnop(OpDecrement, _, target):
        return encodeCompoundAssignment(OpSub, target, {expr: EConst(CInt("1", null)), pos: expr.pos}, writer, expr.pos);
      case EVars(vars):
        return encodeVars(vars, writer, expr.pos);
      case EBinop(OpAssignOp(op), lhs, rhs):
        return encodeCompoundAssignment(op, lhs, rhs, writer, expr.pos);
      case EBinop(OpAssign, lhs, rhs):
        return encodeAssignment(lhs, rhs, writer, expr.pos);
      case EIf(condition, ifBody, elseBody):
        var staticCondition = staticBool(condition);
        if (staticCondition != null) {
          return encodeStatementList(staticCondition ? statementsOf(ifBody) : (elseBody == null ? [] : statementsOf(elseBody)), writer);
        }
        encodeIf(condition, ifBody, elseBody, writer);
      case EReturn(null):
        if (inlineReturnTargets.length > 0) {
          Context.error("Quadrants qdFunc return must return a value", expr.pos);
        }
        writer.u8(STMT_RETURN_VOID);
      case EReturn(returned):
        var inlineReturnTarget = currentInlineReturnTarget();
        var tupleElements = returnTupleElements(returned);
        if (tupleElements != null) {
          if (inlineReturnTarget != null) {
            Context.error("Quadrants qdFunc return cannot return multiple values", expr.pos);
          }
          noteReturnDTypes([for (value in tupleElements) inferExpressionDType(value)], expr.pos);
          writer.u8(STMT_RETURN_VALUES);
          writer.u32(tupleElements.length);
          for (value in tupleElements) {
            encodeExpression(value, writer);
          }
          return 1;
        }
        var inlineCall = inlineFunctionCall(returned);
        var extraCount = 0;
        var valueExpr = returned;
        if (inlineCall != null) {
          var result = emitInlineFunctionToTemp(inlineCall.info, inlineCall.args, writer, returned.pos);
          extraCount = result.count;
          valueExpr = localLoadExpr(result.localId);
        }
        if (inlineReturnTarget != null) {
          writer.u8(STMT_ASSIGN);
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(inlineReturnTarget);
          encodeExpression(valueExpr, writer);
        } else {
          var dtype = inferExpressionDType(valueExpr);
          noteReturn(dtype, expr.pos);
          writer.u8(STMT_RETURN_VALUE);
          encodeExpression(valueExpr, writer);
        }
        return extraCount + 1;
      case ECall(callee, args):
        var hintCount = encodeLoopHintStatement(callee, args, writer, expr.pos);
        if (hintCount != null) {
          return hintCount;
        }
        var builtinCount = encodeBuiltinStatementCall(callee, args, writer, expr.pos);
        if (builtinCount != null) {
          return builtinCount;
        }
        var inlineCall = inlineFunctionCall(expr);
        if (inlineCall != null) {
          return encodeInlineFunctionStatementCall(inlineCall.info, inlineCall.args, writer, expr.pos);
        }
        Context.error("Unsupported Quadrants HashLink kernel statement", expr.pos);
      case ESwitch(subject, switchCases, defaultCase):
        return encodeSwitchStatement(subject, switchCases, defaultCase, writer, expr.pos);
      default:
        Context.error("Unsupported Quadrants HashLink kernel statement", expr.pos);
    }
    return 1;
  }

  function encodeSwitchStatement(subject:Expr, switchCases:Array<Case>, defaultCase:Null<Expr>, writer:ByteWriter, pos:Position):Int {
    var tmpName = '__qdSwitch${switchTempCounter++}';
    var tmpIdent = {expr: EConst(CIdent(tmpName)), pos: pos};
    var elseBranch:Null<Expr> = defaultCase;
    var conditionalCases:Array<{condition:Expr, body:Expr}> = [];
    for (index in 0...switchCases.length) {
      var entry = switchCases[index];
      if (entry.guard != null) {
        Context.error("Unsupported Quadrants HashLink switch pattern; case guards are not supported", entry.guard.pos);
      }
      var body = entry.expr == null ? {expr: EBlock([]), pos: pos} : entry.expr;
      if (entry.values.length == 1 && isWildcardPattern(entry.values[0])) {
        if (elseBranch != null) {
          Context.error("Unsupported Quadrants HashLink switch pattern; duplicate default case", entry.values[0].pos);
        }
        if (index != switchCases.length - 1) {
          Context.error("Unsupported Quadrants HashLink switch pattern; wildcard case must be last", entry.values[0].pos);
        }
        elseBranch = body;
        continue;
      }
      var condition:Null<Expr> = null;
      for (value in entry.values) {
        for (literal in collectSwitchCaseLiterals(value)) {
          var comparison = {expr: EBinop(OpEq, tmpIdent, literal), pos: value.pos};
          condition = condition == null ? comparison : {expr: EBinop(OpBoolOr, condition, comparison), pos: value.pos};
        }
      }
      conditionalCases.push({condition: condition, body: body});
    }
    var chain:Null<Expr> = elseBranch;
    var index = conditionalCases.length - 1;
    while (index >= 0) {
      chain = {expr: EIf(conditionalCases[index].condition, conditionalCases[index].body, chain), pos: pos};
      index--;
    }
    var statements:Array<Expr> = [{expr: EVars([{name: tmpName, type: null, expr: subject}]), pos: pos}];
    if (chain != null) {
      statements.push(chain);
    }
    return encodeStatement({expr: EBlock(statements), pos: pos}, writer);
  }

  function isWildcardPattern(value:Expr):Bool {
    return switch (stripNoCasts(value).expr) {
      case EConst(CIdent("_")): true;
      default: false;
    };
  }

  function collectSwitchCaseLiterals(value:Expr):Array<Expr> {
    var literals:Array<Expr> = [];
    function visit(expression:Expr):Void {
      var expr = stripNoCasts(expression);
      switch (expr.expr) {
        case EBinop(OpOr, lhs, rhs):
          visit(lhs);
          visit(rhs);
        case EConst(CInt(_, _)):
          literals.push(expr);
        case EUnop(OpNeg, false, inner):
          switch (stripNoCasts(inner).expr) {
            case EConst(CInt(_, _)): literals.push(expr);
            default: Context.error("Unsupported Quadrants HashLink switch pattern; use integer literal cases", expr.pos);
          }
        default:
          Context.error("Unsupported Quadrants HashLink switch pattern; use integer literal cases", expr.pos);
      }
    }
    visit(value);
    return literals;
  }

  function encodeBuiltinStatementCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Null<Int> {
    var name = callName(callee, pos);
    var path = callPath(callee, pos);
    var packedCount = encodePackedWriteStatement(path, args, writer, pos);
    if (packedCount != null) {
      return packedCount;
    }
    var compoundCount = encodeCompoundWriteStatement(callee, args, writer, pos);
    if (compoundCount != null) {
      return compoundCount;
    }
    var quantWriteCount = encodeQuantWriteStatement(callee, args, writer, pos);
    if (quantWriteCount != null) {
      return quantWriteCount;
    }
    if (name == "stopGrad") {
      if (args.length != 1) {
        Context.error("Quadrants stopGrad(field) expects one Field parameter argument", pos);
      }
      var stopGradParamId = structForFieldParamId(args[0]);
      if (stopGradParamId == null) {
        Context.error("Quadrants stopGrad requires a direct Field kernel parameter", pos);
      }
      writer.u8(STMT_STOP_GRAD);
      writer.u8(EXPR_ARG_LOAD);
      writer.u32(stopGradParamId);
      return 1;
    }
    var meshAttrWrite = meshAttributeMethodTarget(callee, "write");
    if (meshAttrWrite != null) {
      if (args.length != 2) {
        Context.error("Quadrants MeshAttribute.write(index, value) expects two arguments in kernels", pos);
      }
      writer.u8(STMT_STORE_INDEX);
      encodeArrayBase(meshAttrWrite, writer, 1);
      writer.u32(1);
      encodeArrayIndices(meshAttrWrite, [args[0]], writer);
      encodeExpression(args[1], writer);
      return 1;
    }
    var scalarWriteTarget = tensorMethodTarget(callee, "scalarWrite");
    if (scalarWriteTarget == null && name == "scalarWrite" && args.length == 2) {
      scalarWriteTarget = args[0];
      args = [args[1]];
    }
    if (scalarWriteTarget != null) {
      if (args.length != 1) {
        Context.error("Quadrants HashLink Tensor.scalarWrite(value) expects one argument", pos);
      }
      writer.u8(STMT_STORE_INDEX);
      encodeArrayBase(scalarWriteTarget, writer, 0);
      writer.u32(0);
      encodeArrayIndices(scalarWriteTarget, [], writer);
      encodeExpression(args[0], writer);
      return 1;
    }
    var writeTarget = tensorMethodTarget(callee, "write");
    if (writeTarget == null) {
      writeTarget = tensorMethodTarget(callee, "kernelWrite");
    }
    if (writeTarget == null && (name == "write" || name == "kernelWrite") && args.length == 3) {
      writeTarget = args[0];
      args = [args[1], args[2]];
    }
    if (writeTarget != null) {
      if (args.length != 2) {
        Context.error("Quadrants HashLink Tensor.write(index, value) expects two arguments", pos);
      }
      writer.u8(STMT_STORE_INDEX);
      encodeArrayBase(writeTarget, writer, 1);
      writer.u32(1);
      encodeArrayIndices(writeTarget, [args[0]], writer);
      encodeExpression(args[1], writer);
      return 1;
    }
    var snodeStmtCount = encodeSNodeStatementCall(callee, args, writer, pos);
    if (snodeStmtCount != null) {
      return snodeStmtCount;
    }
    var internalStmt = internalStatementOpcode(path);
    if (internalStmt != null) {
      writer.u8(internalStmt);
      if (internalStmt == STMT_WARP_BARRIER) {
        if (args.length != 1) {
          Context.error("Quadrants HashLink Block.warpSync expects one mask argument", pos);
        }
        encodeExpression(args[0], writer);
      } else if (args.length != 0) {
        Context.error('Quadrants HashLink statement ${path} expects no arguments', pos);
      }
      return 1;
    }
    switch (name) {
      case "print":
        if (args.length < 1 || args.length > 16) {
          Context.error("Quadrants HashLink print expects one to sixteen arguments", pos);
        }
        var entries = collectPrintEntries(args);
        entries.push({text: "\n", value: null});
        writer.u8(STMT_PRINT_ENTRIES);
        writer.u32(entries.length);
        for (entry in entries) {
          if (entry.text != null) {
            writer.u8(0);
            writer.string(entry.text);
          } else {
            writer.u8(1);
            encodeExpression(entry.value, writer);
          }
        }
        return 1;
      case "assert":
        if (args.length < 1 || args.length > 2) {
          Context.error("Quadrants HashLink assert expects a condition and optional string message", pos);
        }
        writer.u8(STMT_ASSERT);
        encodeExpression(args[0], writer);
        if (args.length == 2) {
          var message = switch (strip(args[1]).expr) {
            case EConst(CString(value, _)): value;
            default: Context.error("Quadrants HashLink assert message must be a string literal", args[1].pos);
          };
          writer.u8(1);
          writer.string(message);
        } else {
          writer.u8(0);
        }
        return 1;
      default:
        return null;
    }
  }

  function collectPrintEntries(args:Array<Expr>):Array<{text:Null<String>, value:Null<Expr>}> {
    var entries:Array<{text:Null<String>, value:Null<Expr>}> = [];
    for (index in 0...args.length) {
      if (index > 0) {
        entries.push({text: " ", value: null});
      }
      appendPrintEntry(args[index], entries);
    }
    return entries;
  }

  function appendPrintEntry(expression:Expr, entries:Array<{text:Null<String>, value:Null<Expr>}>):Void {
    var expr = strip(expression);
    switch (expr.expr) {
      case EConst(CString(value, SingleQuotes)):
        entries.push({text: value, value: null});
      case EConst(CString(value, _)):
        entries.push({text: value, value: null});
      case EBinop(OpAdd, _, _) if (concatContainsStringLiteral(expr)):
        flattenPrintConcat(expr, entries);
      default:
        entries.push({text: null, value: expression});
    }
  }

  function concatContainsStringLiteral(expression:Expr):Bool {
    return switch (strip(expression).expr) {
      case EConst(CString(_, _)): true;
      case EBinop(OpAdd, lhs, rhs): concatContainsStringLiteral(lhs) || concatContainsStringLiteral(rhs);
      default: false;
    };
  }

  function flattenPrintConcat(expression:Expr, entries:Array<{text:Null<String>, value:Null<Expr>}>):Void {
    var expr = strip(expression);
    switch (expr.expr) {
      case EBinop(OpAdd, lhs, rhs) if (concatContainsStringLiteral(lhs) || concatContainsStringLiteral(rhs)):
        flattenPrintConcat(lhs, entries);
        flattenPrintConcat(rhs, entries);
      case EConst(CString(value, _)):
        entries.push({text: value, value: null});
      default:
        entries.push({text: null, value: expr});
    }
  }


  function encodePackedWriteStatement(path:String, args:Array<Expr>, writer:ByteWriter, pos:Position):Null<Int> {
    var width = -1;
    var dtype = DTYPE_I32;
    var isMatrix = false;
    var isMember = false;
    if (StringTools.endsWith(path, "PackedHelpers.writeVec2I32")) {
      width = 2;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeVec3I32")) {
      width = 3;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeVec4I32")) {
      width = 4;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeVec2F32")) {
      width = 2;
      dtype = DTYPE_F32;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeVec3F32")) {
      width = 3;
      dtype = DTYPE_F32;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeVec4F32")) {
      width = 4;
      dtype = DTYPE_F32;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeMat2I32")) {
      width = 4;
      dtype = DTYPE_I32;
      isMatrix = true;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeMat2F32")) {
      width = 4;
      dtype = DTYPE_F32;
      isMatrix = true;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeMemberI32")) {
      width = 1;
      dtype = DTYPE_I32;
      isMember = true;
    } else if (StringTools.endsWith(path, "PackedHelpers.writeMemberF32")) {
      width = 1;
      dtype = DTYPE_F32;
      isMember = true;
    }
    if (width < 0) return null;
    if (args.length != 3) {
      Context.error("Quadrants packed write helper expects storage, index, and value", pos);
    }
    var name = isMember ? null : (isMatrix ? directMatrixName(args[2]) : directVectorName(args[2]));
    if (!isMember && name == null) {
      Context.error("Quadrants packed write helper value must be a kernel vector or matrix local", args[2].pos);
    }
    for (component in 0...width) {
      writer.u8(STMT_STORE_INDEX);
      encodeArrayBase(args[0], writer, 1);
      writer.u32(1);
      encodeArrayIndices(args[0], [isMember ? args[1] : packedOffsetExpr(args[1], width, component, pos)], writer);
      if (isMember) {
        encodeExpressionWithExpectedDType(args[2], dtype, writer);
      } else if (isMatrix) {
        encodeExpressionWithExpectedDType(matrixElementExpr(name, Std.int(component / 2), component % 2, pos), dtype, writer);
      } else {
        encodeExpressionWithExpectedDType(vectorComponentExpr(name, component, pos), dtype, writer);
      }
    }
    return width;
  }

  function encodeCompoundWriteStatement(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Null<Int> {
    return switch (strip(callee).expr) {
      case EField(base, method):
        var width = compoundVectorWidth(method, "writeVec");
        var isMatrix = false;
        var matrixDim = 0;
        if (width < 0) {
          matrixDim = compoundMatrixDim(method, "writeMat");
          if (matrixDim > 0) {
            width = matrixDim * matrixDim;
            isMatrix = true;
          }
        }
        if (width < 0) {
          null;
        } else {
          if (args.length != 2) {
            Context.error("Quadrants compound write expects index and value", pos);
          }
          var dtype = arrayBaseDType(base, pos);
          var valueExpressions:Array<Expr>;
          if (isMatrix) {
            var name = directMatrixName(args[1]);
            if (name != null) {
              valueExpressions = [for (component in 0...width) matrixElementExpr(name, Std.int(component / matrixDim), component % matrixDim, pos)];
            } else {
              var init = matrixInitializer(args[1]);
              if (init == null || init.rows != matrixDim || init.cols != matrixDim) {
                Context.error("Quadrants compound matrix write value must be a matching kernel matrix", args[1].pos);
              }
              valueExpressions = init.values;
            }
          } else {
            var name = directVectorName(args[1]);
            if (name != null) {
              valueExpressions = [for (component in 0...width) vectorComponentExpr(name, component, pos)];
            } else {
              var init = vectorInitializer(args[1]);
              if (init == null || init.values.length != width) {
                Context.error("Quadrants compound vector write value must be a matching kernel vector", args[1].pos);
              }
              valueExpressions = init.values;
            }
          }
          for (component in 0...width) {
            writer.u8(STMT_STORE_INDEX);
            encodeArrayBase(base, writer, 1);
            writer.u32(1);
            encodeArrayIndices(base, [packedOffsetExpr(args[0], width, component, pos)], writer);
            encodeExpressionWithExpectedDType(valueExpressions[component], dtype, writer);
          }
          width;
        }
      default:
        null;
    };
  }

  function compoundVectorWidth(method:String, prefix:String):Int {
    if (!StringTools.startsWith(method, prefix)) {
      return -1;
    }
    return switch (method.substr(prefix.length)) {
      case "2": 2;
      case "3": 3;
      case "4": 4;
      default: -1;
    };
  }

  function compoundMatrixDim(method:String, prefix:String):Int {
    if (!StringTools.startsWith(method, prefix)) {
      return -1;
    }
    return switch (method.substr(prefix.length)) {
      case "2": 2;
      case "3": 3;
      case "4": 4;
      default: -1;
    };
  }

  function arrayBaseDType(base:Expr, pos:Position):Int {
    return switch (strip(base).expr) {
      case EConst(CIdent(name)):
        var inlineArg = lookupInlineArg(name);
        if (inlineArg != null && directIdentifier(inlineArg) != name) {
          inferExpressionDType(inlineArg);
        } else {
          var localId = lookupLocal(name);
          if (localId != null) {
            locals[localId].dtype;
          } else {
            var paramId = paramIds.get(name);
            if (paramId == null) {
              Context.error('Quadrants ndarray ${name} is not a kernel parameter', pos);
            }
            params[paramId].dtype;
          }
        }
      default:
        DTYPE_I32;
    };
  }


  function packedOffsetExpr(index:Expr, width:Int, component:Int, pos:Position):Expr {
    var offset = binaryExpr(OpMult, index, intLiteralExpr(width, pos), pos);
    return component == 0 ? offset : binaryExpr(OpAdd, offset, intLiteralExpr(component, pos), pos);
  }
  function encodeLoopHintStatement(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Null<Int> {
    var name = callName(callee, pos);
    switch (name) {
      case "blockDim" | "block_dim":
        if (args.length != 1) {
          Context.error("Quadrants HashLink blockDim expects one integer literal", pos);
        }
        var value = constantIndex(args[0], args[0].pos);
        if (value <= 0) {
          Context.error("Quadrants HashLink blockDim must be positive", args[0].pos);
        }
        writer.u8(STMT_BLOCK_DIM);
        writer.u32(value);
        return 1;
      case "parallelize":
        if (args.length != 1) {
          Context.error("Quadrants HashLink parallelize expects one integer literal", pos);
        }
        var value = constantIndex(args[0], args[0].pos);
        if (value <= 0) {
          Context.error("Quadrants HashLink parallelize count must be positive", args[0].pos);
        }
        writer.u8(STMT_PARALLELIZE);
        writer.u32(value);
        return 1;
      case "serialize" | "strictlySerialize":
        if (args.length != 0) {
          Context.error("Quadrants HashLink serialize expects no arguments", pos);
        }
        writer.u8(STMT_SERIALIZE);
        writer.u32(0);
        return 1;
      default:
        return null;
    }
  }

  function encodeStatementList(statements:Array<Expr>, writer:ByteWriter):Int {
    var count = 0;
    for (statement in statements) {
      count += encodeStatement(statement, writer);
    }
    return count;
  }

  function encodeRangeFor(iterator:Expr, body:Expr, writer:ByteWriter, pos:Position):Int {
    switch (strip(iterator).expr) {
      case EBinop(OpIn, loopVariable, range):
        var loopName = requireIdent(loopVariable, "Quadrants range-for loop variable must be an identifier");
        var rangeExpr = strip(range);
        switch (rangeExpr.expr) {
          case EBinop(OpInterval, begin, end):
            encodeSimpleRangeFor(loopName, loopVariable.pos, begin, end, body, writer);
            return 1;
          case ECall(callee, args):
            if (isStaticRangeCall(callee)) {
              return encodeStaticRangeFor(loopName, args, body, writer, rangeExpr.pos);
            }
            if (isStaticValuesCall(callee)) {
              return encodeStaticValuesFor(loopName, args, body, writer, rangeExpr.pos);
            }
            var meshInfo = meshForInfo(callee, args);
            if (meshInfo != null) {
              encodeMeshFor(loopName, loopVariable.pos, meshInfo, body, writer);
              return 1;
            }
            if (isGroupedCall(callee)) {
              var structTarget = groupedStructForTarget(args);
              if (structTarget != null) {
                var fieldParamId = structForFieldParamId(structTarget);
                if (fieldParamId != null) {
                  var groupRank = args.length >= 2 ? staticIntLiteral(args[1], args[1].pos) : 1;
                  encodeStructForField(loopName, loopVariable.pos, fieldParamId, groupRank, body, writer);
                  return 1;
                }
                if (args.length >= 2) {
                  Context.error("Quadrants Grouped.of rank argument requires a Field kernel parameter target", args[1].pos);
                }
                encodeStructForExternalTensor(loopName, loopVariable.pos, structTarget, body, writer);
                return 1;
              }
              var groupedInfo = groupedNdrangeForInfo(args, rangeExpr.pos);
              encodeNdrangeBoundsFor(loopName, groupedInfo.begins, groupedInfo.ends, groupedInfo.axes, body, writer, rangeExpr.pos);
              return 1;
            }
            var ndrangeInfo = ndrangeForInfo(callee, args, rangeExpr.pos);
            if (ndrangeInfo != null) {
              encodeNdrangeBoundsFor(loopName, ndrangeInfo.begins, ndrangeInfo.ends, ndrangeInfo.axes, body, writer, rangeExpr.pos);
              return 1;
            }
            Context.error("Quadrants HashLink range-for only supports start...end, Ndrange.of*/ranges* helpers, Grouped.of(...), Static.range(...), or Mesh.forVertices/forEdges/forFaces/forCells(...)", rangeExpr.pos);
          case EConst(CIdent(name)):
            var paramId = paramIds.get(name);
            if (paramId != null && (params[paramId].kind == PARAM_NDARRAY || params[paramId].kind == PARAM_FIELD)) {
              encodeStructForExternalTensor(loopName, loopVariable.pos, rangeExpr, body, writer);
              return 1;
            } else {
              Context.error("Quadrants HashLink range-for only supports start...end, Ndrange.of*/ranges* helpers, Grouped.of(...), Static.range(...), or Mesh.forVertices/forEdges/forFaces/forCells(...)", rangeExpr.pos);
            }
          default:
            Context.error("Quadrants HashLink range-for only supports start...end, Ndrange.of*/ranges* helpers, Grouped.of(...), Static.range(...), or Mesh.forVertices/forEdges/forFaces/forCells(...)", rangeExpr.pos);
        }
      default:
        Context.error("Quadrants HashLink only supports for (i in start...end)", pos);
    }
    return 1;
  }

  function encodeSimpleRangeFor(loopName:String, loopPos:Position, begin:Expr, end:Expr, body:Expr, writer:ByteWriter):Void {
    var rangeBounds = new ByteWriter();
    encodeExpression(begin, rangeBounds);
    encodeExpression(end, rangeBounds);

    var bodyBytes = new ByteWriter();
    pushScope();
    var localId = declareLocal(loopName, loopPos, false, DTYPE_I32);
    loopDepth++;
    var bodyCount = encodeStatementList(statementsOf(body), bodyBytes);
    loopDepth--;
    popScope();

    writer.u8(STMT_RANGE_FOR);
    writer.u32(localId);
    writer.append(rangeBounds.bytes);
    writer.u32(bodyCount);
    writer.append(bodyBytes.bytes);
  }

  function encodeStaticRangeFor(loopName:String, bounds:Array<Expr>, body:Expr, writer:ByteWriter, pos:Position):Int {
    if (bounds.length != 2) {
      Context.error("Quadrants Static.range expects begin and end integer literals", pos);
    }
    var begin = staticIntLiteral(bounds[0], bounds[0].pos);
    var end = staticIntLiteral(bounds[1], bounds[1].pos);
    if (end - begin > STATIC_UNROLL_LIMIT) {
      Context.error('Quadrants static unroll exceeds limit ${STATIC_UNROLL_LIMIT}', pos);
    }
    var count = 0;
    for (value in begin...end) {
      var argScope = new Map<String, Expr>();
      argScope[loopName] = {expr: EConst(CInt(Std.string(value), null)), pos: pos};
      inlineArgScopes.push(argScope);
      pushScope();
      count += encodeStatementList(statementsOf(body), writer);
      popScope();
      inlineArgScopes.pop();
    }
    return count;
  }

  function encodeStaticValuesFor(loopName:String, args:Array<Expr>, body:Expr, writer:ByteWriter, pos:Position):Int {
    if (args.length != 1) {
      Context.error("Quadrants Static.values expects one array literal argument", pos);
    }
    var elements = switch (stripNoCasts(args[0]).expr) {
      case EArrayDecl(values): values;
      default: Context.error("Quadrants Static.values expects an array literal", args[0].pos);
    };
    if (elements.length == 0) {
      Context.error("Quadrants Static.values requires at least one literal element", args[0].pos);
    }
    if (elements.length > STATIC_UNROLL_LIMIT) {
      Context.error('Quadrants static unroll exceeds limit ${STATIC_UNROLL_LIMIT}', pos);
    }
    var count = 0;
    for (element in elements) {
      var literal = staticScalarLiteralExpr(element);
      var argScope = new Map<String, Expr>();
      argScope[loopName] = literal;
      inlineArgScopes.push(argScope);
      pushScope();
      count += encodeStatementList(statementsOf(body), writer);
      popScope();
      inlineArgScopes.pop();
    }
    return count;
  }

  function staticScalarLiteralExpr(expression:Expr):Expr {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case EConst(CInt(_, _)) | EConst(CFloat(_, _)):
        expr;
      case EUnop(OpNeg, false, inner):
        switch (stripNoCasts(inner).expr) {
          case EConst(CInt(_, _)) | EConst(CFloat(_, _)): expr;
          default: Context.error("Quadrants Static.values elements must be integer or float literals", expr.pos);
        }
      case ECall(callee, callArgs) if (isStaticValueCall(callee) && callArgs.length == 1):
        staticScalarLiteralExpr(callArgs[0]);
      default:
        Context.error("Quadrants Static.values elements must be integer or float literals", expr.pos);
    };
  }

  function staticIntLiteral(expression:Expr, pos:Position):Int {
    return switch (stripNoCasts(expression).expr) {
      case EConst(CInt(value, _)):
        var parsed = Std.parseInt(value);
        if (parsed == null) {
          Context.error('Invalid static integer literal ${value}', pos);
        }
        parsed;
      case ECall(callee, args) if (isStaticValueCall(callee)):
        if (args.length != 1) {
          Context.error("Quadrants Static.value expects one argument", pos);
        }
        staticIntLiteral(args[0], args[0].pos);
      default:
        Context.error("Quadrants Static.range bounds must be integer literals", pos);
    };
  }

  function meshForInfo(callee:Expr, args:Array<Expr>):Null<MeshForInfo> {
    var path = callPath(callee, callee.pos);
    var elementType = if (pathIs(path, "Mesh", "forVertices")) {
      0;
    } else if (pathIs(path, "Mesh", "forEdges")) {
      1;
    } else if (pathIs(path, "Mesh", "forFaces")) {
      2;
    } else if (pathIs(path, "Mesh", "forCells")) {
      3;
    } else {
      return null;
    }
    if (args.length != 1) {
      Context.error('Quadrants ${path} expects one integer literal element count', callee.pos);
    }
    var count = staticIntLiteral(args[0], args[0].pos);
    if (count < 0) {
      Context.error("Quadrants mesh-for element count must be non-negative", args[0].pos);
    }
    var counts = [0, 0, 0, 0];
    counts[elementType] = count;
    return {elementType: elementType, counts: counts};
  }

  function encodeMeshFor(loopName:String, loopPos:Position, info:MeshForInfo, body:Expr, writer:ByteWriter):Void {
    var bodyBytes = new ByteWriter();
    pushScope();
    var localId = declareLocal(loopName, loopPos, false, DTYPE_I32);
    loopDepth++;
    var bodyCount = encodeStatementList(statementsOf(body), bodyBytes);
    loopDepth--;
    popScope();

    writer.u8(STMT_MESH_FOR);
    writer.u32(localId);
    writer.u8(info.elementType);
    for (count in info.counts) {
      writer.u32(count);
    }
    writer.u32(bodyCount);
    writer.append(bodyBytes.bytes);
  }

  function encodeStructForExternalTensor(loopName:String, loopPos:Position, iterable:Expr, body:Expr, writer:ByteWriter):Void {
    var target = strip(iterable);
    var paramId = switch (target.expr) {
      case EConst(CIdent(name)):
        var id = paramIds.get(name);
        if (id == null) {
          Context.error('Quadrants struct-for target ${name} is not a kernel Tensor or Field parameter', target.pos);
        }
        id;
      default:
        Context.error("Quadrants struct-for target must be a direct Tensor or Field parameter", target.pos);
    };
    var param = params[paramId];
    if (param.kind == PARAM_SCALAR) {
      Context.error('Quadrants parameter ${param.name} is used as both scalar and struct-for target', target.pos);
    }
    if (param.kind == PARAM_FIELD) {
      encodeStructForField(loopName, loopPos, paramId, 1, body, writer);
      return;
    }
    param.kind = PARAM_NDARRAY;
    if (param.rank == 0) {
      param.rank = 1;
      param.rankFromShape = true;
    }

    var bodyBytes = new ByteWriter();
    pushScope();
    var localId = declareLocal(loopName, loopPos, false, DTYPE_I32);
    loopDepth++;
    var bodyCount = encodeStatementList(statementsOf(body), bodyBytes);
    loopDepth--;
    popScope();

    writer.u8(STMT_STRUCT_FOR_EXTERNAL_TENSOR);
    writer.u32(localId);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(paramId);
    writer.u32(bodyCount);
    writer.append(bodyBytes.bytes);
  }

  function structForFieldParamId(target:Expr):Null<Int> {
    return switch (strip(target).expr) {
      case EConst(CIdent(name)):
        var paramId = paramIds.get(name);
        paramId != null && params[paramId].kind == PARAM_FIELD ? paramId : null;
      default:
        null;
    };
  }

  function encodeStructForField(loopName:String, loopPos:Position, paramId:Int, groupRank:Int, body:Expr, writer:ByteWriter):Void {
    if (groupRank < 1 || groupRank > 8) {
      Context.error("Quadrants field struct-for rank must be in 1...8", loopPos);
    }
    markParamField(paramId, groupRank, loopPos);
    var bodyBytes = new ByteWriter();
    pushScope();
    var localIds:Array<Int> = [];
    if (groupRank == 1) {
      localIds.push(declareLocal(loopName, loopPos, false, DTYPE_I32));
    } else {
      var vectorScope = new Map<String, Array<Int>>();
      for (dim in 0...groupRank) {
        localIds.push(declareLocal('__qd_${loopName}_${dim}', loopPos, false, DTYPE_I32));
      }
      vectorScope[loopName] = localIds;
      indexVectorScopes.push(vectorScope);
    }
    loopDepth++;
    var bodyCount = encodeStatementList(statementsOf(body), bodyBytes);
    loopDepth--;
    if (groupRank > 1) {
      indexVectorScopes.pop();
    }
    popScope();

    writer.u8(STMT_STRUCT_FOR_FIELD);
    writer.u32(localIds.length);
    for (id in localIds) {
      writer.u32(id);
    }
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(paramId);
    writer.u32(bodyCount);
    writer.append(bodyBytes.bytes);
  }

  function identityAxes(rank:Int):Array<Int> {
    return [for (axis in 0...rank) axis];
  }

  function parseNdrangeOfInfo(methodName:String, bounds:Array<Expr>, fixedRank:Int, axesExpr:Null<Expr>, pos:Position):NdrangeForInfo {
    var rank = fixedRank == 0 ? bounds.length : fixedRank;
    if (fixedRank == 0) {
      if (bounds.length == 0 || bounds.length > 4) {
        Context.error('Quadrants ${methodName} supports one to four dimensions', pos);
      }
    } else if (bounds.length != fixedRank) {
      Context.error('Quadrants ${methodName} expects ${fixedRank} dimension argument(s)', pos);
    }

    var begins:Array<Expr> = [];
    var ends:Array<Expr> = [];
    for (bound in bounds) {
      begins.push({expr: EConst(CInt("0", null)), pos: pos});
      ends.push(bound);
    }
    return {begins: begins, ends: ends, axes: axesForExpr(methodName, rank, axesExpr)};
  }

  function parseNdrangeRangesInfo(methodName:String, args:Array<Expr>, fixedRank:Int, axesExpr:Null<Expr>, pos:Position):NdrangeForInfo {
    var rank = fixedRank == 0 ? Std.int(args.length / 2) : fixedRank;
    if (fixedRank == 0) {
      if (args.length == 0 || args.length > 8 || args.length % 2 != 0) {
        Context.error('Quadrants ${methodName} supports one to four begin/end pairs', pos);
      }
    } else if (args.length != fixedRank * 2) {
      Context.error('Quadrants ${methodName} expects ${fixedRank} begin/end pair(s)', pos);
    }

    var begins:Array<Expr> = [];
    var ends:Array<Expr> = [];
    for (i in 0...rank) {
      begins.push(args[i * 2]);
      ends.push(args[i * 2 + 1]);
    }
    return {begins: begins, ends: ends, axes: axesForExpr(methodName, rank, axesExpr)};
  }

  function ndrangeForInfo(callee:Expr, args:Array<Expr>, pos:Position):Null<NdrangeForInfo> {
    var path = callPath(callee, callee.pos);
    for (rank in 1...5) {
      var ofName = "of" + rank;
      if (pathIs(path, "Ndrange", ofName)) {
        return parseNdrangeOfInfo("Ndrange." + ofName, args, rank, null, pos);
      }
      var ofAxesName = ofName + "Axes";
      if (pathIs(path, "Ndrange", ofAxesName)) {
        if (args.length == 0) {
          Context.error('Quadrants Ndrange.${ofAxesName} expects ${rank} dimension argument(s) and AxisOrder.of${rank}(...)', pos);
        }
        var axesExpr = args[args.length - 1];
        return parseNdrangeOfInfo("Ndrange." + ofAxesName, args.slice(0, args.length - 1), rank, axesExpr, pos);
      }
      var rangesName = "ranges" + rank;
      if (pathIs(path, "Ndrange", rangesName)) {
        return parseNdrangeRangesInfo("Ndrange." + rangesName, args, rank, null, pos);
      }
      var rangesAxesName = rangesName + "Axes";
      if (pathIs(path, "Ndrange", rangesAxesName)) {
        if (args.length == 0) {
          Context.error('Quadrants Ndrange.${rangesAxesName} expects ${rank} begin/end pair(s) and AxisOrder.of${rank}(...)', pos);
        }
        var axesExpr = args[args.length - 1];
        return parseNdrangeRangesInfo("Ndrange." + rangesAxesName, args.slice(0, args.length - 1), rank, axesExpr, pos);
      }
    }
    if (pathIs(path, "Ndrange", "of")) {
      return parseNdrangeOfInfo("Ndrange.of", args, 0, null, pos);
    }
    if (pathIs(path, "Ndrange", "ranges")) {
      return parseNdrangeRangesInfo("Ndrange.ranges", args, 0, null, pos);
    }
    return null;
  }

  function groupedNdrangeForInfo(args:Array<Expr>, pos:Position):NdrangeForInfo {
    if (args.length == 0) {
      Context.error("Quadrants Grouped.of expects a Tensor/Field parameter, Ndrange domain, or one to four dimensions", pos);
    }
    if (args.length == 1) {
      switch (strip(args[0]).expr) {
        case ECall(callee, nestedArgs):
          var nested = ndrangeForInfo(callee, nestedArgs, args[0].pos);
          if (nested != null) {
            return nested;
          }
        default:
      }
    }
    return parseNdrangeOfInfo("Grouped.of", args, 0, null, pos);
  }

  function axesForExpr(methodName:String, rank:Int, axesExpr:Null<Expr>):Array<Int> {
    if (axesExpr == null) {
      return identityAxes(rank);
    }
    var expectedName = 'of${rank}';
    return switch (strip(axesExpr).expr) {
      case ECall(callee, args):
        var path = callPath(callee, callee.pos);
        if (!pathIs(path, "AxisOrder", expectedName)) {
          Context.error('Quadrants ${methodName} expects AxisOrder.${expectedName}(...)', axesExpr.pos);
        }
        if (args.length != rank) {
          Context.error('Quadrants AxisOrder.${expectedName} expects ${rank} axis literal(s)', axesExpr.pos);
        }
        var seen = [for (_ in 0...rank) false];
        var axes:Array<Int> = [];
        for (arg in args) {
          var axis = staticAxisLiteral(arg, arg.pos);
          if (axis < 0 || axis >= rank || seen[axis]) {
            Context.error('Quadrants AxisOrder.${expectedName} arguments must be a permutation of 0...${rank}', arg.pos);
          }
          seen[axis] = true;
          axes.push(axis);
        }
        axes;
      default:
        Context.error('Quadrants ${methodName} expects AxisOrder.${expectedName}(...)', axesExpr.pos);
    }
  }

  function staticAxisLiteral(expression:Expr, pos:Position):Int {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case EConst(CInt(value, _)):
        var parsed = Std.parseInt(value);
        if (parsed == null) {
          Context.error('Invalid static axis literal ${value}', pos);
        }
        parsed;
      case EUnop(OpNeg, false, inner):
        -staticAxisLiteral(inner, inner.pos);
      case EField(_, _):
        var path = callPath(expr, pos);
        switch (path) {
          case "Axis.i" | "quadrants.Axis.i": 0;
          case "Axis.j" | "quadrants.Axis.j": 1;
          case "Axis.k" | "quadrants.Axis.k": 2;
          case "Axis.l" | "quadrants.Axis.l": 3;
          default:
            Context.error("Quadrants AxisOrder axes must be integer literals or Axis.i/Axis.j/Axis.k/Axis.l", pos);
        }
      default:
        Context.error("Quadrants AxisOrder axes must be integer literals or Axis.i/Axis.j/Axis.k/Axis.l", pos);
    };
  }

  function encodeNdrangeBoundsFor(loopName:String, begins:Array<Expr>, ends:Array<Expr>, axes:Array<Int>, body:Expr, writer:ByteWriter, pos:Position):Void {
    var localIds:Array<Int> = [];
    var vectorScope = new Map<String, Array<Int>>();
    var bodyBytes = new ByteWriter();
    pushScope();
    for (dim in 0...ends.length) {
      localIds.push(declareLocal('__qd_${loopName}_${dim}', pos, false, DTYPE_I32));
    }
    vectorScope[loopName] = localIds;
    indexVectorScopes.push(vectorScope);
    loopDepth += ends.length;
    var bodyCount = encodeStatementList(statementsOf(body), bodyBytes);
    loopDepth -= ends.length;
    indexVectorScopes.pop();
    popScope();

    var nestedBytes = bodyBytes;
    var nestedCount = bodyCount;
    var orderIndex = axes.length;
    while (orderIndex > 0) {
      orderIndex--;
      var dim = axes[orderIndex];
      var next = new ByteWriter();
      next.u8(STMT_RANGE_FOR);
      next.u32(localIds[dim]);
      encodeExpression(begins[dim], next);
      encodeExpression(ends[dim], next);
      next.u32(nestedCount);
      next.append(nestedBytes.bytes);
      nestedBytes = next;
      nestedCount = 1;
    }
    writer.append(nestedBytes.bytes);
  }

  function encodeWhile(condition:Expr, body:Expr, writer:ByteWriter):Void {
    var bodyBytes = new ByteWriter();
    pushScope();
    loopDepth++;
    var bodyCount = encodeStatementList(statementsOf(body), bodyBytes);
    loopDepth--;
    popScope();

    writer.u8(STMT_WHILE);
    encodeExpression(condition, writer);
    writer.u32(bodyCount);
    writer.append(bodyBytes.bytes);
  }

  function encodeIf(condition:Expr, ifBody:Expr, elseBody:Null<Expr>, writer:ByteWriter):Void {
    var ifBytes = new ByteWriter();
    pushScope();
    var ifCount = encodeStatementList(statementsOf(ifBody), ifBytes);
    popScope();

    var elseBytes = new ByteWriter();
    var elseCount = 0;
    if (elseBody != null) {
      pushScope();
      elseCount = encodeStatementList(statementsOf(elseBody), elseBytes);
      popScope();
    }

    writer.u8(STMT_IF);
    encodeExpression(condition, writer);
    writer.u32(ifCount);
    writer.append(ifBytes.bytes);
    writer.u32(elseCount);
    writer.append(elseBytes.bytes);
  }

  function encodeVars(vars:Array<Var>, writer:ByteWriter, pos:Position):Int {
    if (vars.length != 1) {
      Context.error("Quadrants HashLink supports one local variable declaration per statement", pos);
    }
    var local = vars[0];
    if (local.expr != null) {
      var sharedInit = sharedLocalInitializer(local.expr);
      if (sharedInit != null) {
        declareSharedLocal(local.name, pos, sharedInit.dtype, sharedInit.size);
        return 0;
      }
      var frexpInit = frexpStructInitializer(local.expr);
      if (frexpInit != null) {
        return encodeStructDeclaration(local.name, pos, frexpInit, writer);
      }
      var resourceLoad = structWholeAccess(local.expr);
      if (resourceLoad != null) {
        return encodeStructResourceLoadDeclaration(local.name, pos, resourceLoad, writer);
      }
      var structInit = structInitializer(local.expr);
      if (structInit != null) {
        return encodeStructDeclaration(local.name, pos, structInit, writer);
      }
      var matrixInit = matrixInitializer(local.expr);
      if (matrixInit != null) {
        return encodeMatrixDeclaration(local.name, pos, matrixInit, writer);
      }
      var vectorInit = vectorInitializer(local.expr);
      if (vectorInit != null) {
        return encodeVectorDeclaration(local.name, pos, vectorInit, writer);
      }
    }
    var localDType = local.type == null ? DTYPE_I32 : dtypeFromComplexType(local.type, pos);
    var localId = declareLocal(local.name, pos, true, localDType);
    if (local.expr == null) {
      writer.u8(STMT_LOCAL_ALLOC);
      writer.u32(localId);
      return 1;
    }
    var inlineCall = inlineFunctionCall(local.expr);
    var extraCount = 0;
    var valueExpr = local.expr;
    if (inlineCall != null) {
      var result = emitInlineFunctionToTemp(inlineCall.info, inlineCall.args, writer, local.expr.pos);
      extraCount = result.count;
      valueExpr = localLoadExpr(result.localId);
    }
    writer.u8(STMT_ASSIGN);
    writer.u8(EXPR_LOCAL_LOAD);
    writer.u32(localId);
    encodeExpressionWithExpectedDType(valueExpr, localDType, writer);
    return extraCount + 1;
  }

  function sharedLocalInitializer(expression:Expr):Null<{dtype:Int, size:Int}> {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case ECall(callee, args):
        var path = callPath(callee, expr.pos);
        if (path == "Shared.array" || path == "quadrants.Shared.array") {
          if (args.length != 2) {
            Context.error("Quadrants generic shared array expects a DType and one integer literal size", expr.pos);
          }
          {dtype: sharedGenericDType(args[0], args[0].pos), size: staticIntLiteral(args[1], args[1].pos)};
        } else if (path == "Shared.tile16" || path == "quadrants.Shared.tile16") {
          if (args.length != 1) {
            Context.error("Quadrants generic shared tile16 expects one DType argument", expr.pos);
          }
          {dtype: sharedGenericDType(args[0], args[0].pos), size: 256};
        } else {
          var tileSize = path.indexOf("Shared.tile16") == 0 || path.indexOf("quadrants.Shared.tile16") == 0 ? 256 : 0;
          var dtype = sharedDTypeForPath(path, tileSize > 0 ? "tile16" : "array");
          if (dtype < 0) {
            null;
          } else if (tileSize > 0) {
            if (args.length != 0) {
              Context.error("Quadrants shared tile16 factory expects no arguments", expr.pos);
            }
            {dtype: dtype, size: tileSize};
          } else {
            if (args.length != 1) {
              Context.error("Quadrants shared array factory expects one integer literal size", expr.pos);
            }
            {dtype: dtype, size: staticIntLiteral(args[0], args[0].pos)};
          }
        }
      default:
        null;
    };
  }

  function sharedDTypeForPath(path:String, prefix:String):Int {
    var shortPrefix = 'Shared.${prefix}';
    var qualifiedPrefix = 'quadrants.Shared.${prefix}';
    var suffix = if (path.indexOf(shortPrefix) == 0) {
      path.substr(shortPrefix.length);
    } else if (path.indexOf(qualifiedPrefix) == 0) {
      path.substr(qualifiedPrefix.length);
    } else {
      "";
    };
    return dtypeSuffix(suffix);
  }

  function sharedGenericDType(expression:Expr, pos:Position):Int {
    return switch (strip(expression).expr) {
      case EField(_, name), EConst(CIdent(name)):
        var dtype = dtypeSuffix(name);
        if (dtype < 0) {
          Context.error("Quadrants generic shared local expects a concrete DType enum value", pos);
        }
        dtype;
      default:
        Context.error("Quadrants generic shared local expects a concrete DType enum value", pos);
    };
  }

  function dtypeSuffix(suffix:String):Int {
    return switch (suffix) {
      case "I8": DTYPE_I8;
      case "I16": DTYPE_I16;
      case "I32": DTYPE_I32;
      case "I64": DTYPE_I64;
      case "U8": DTYPE_U8;
      case "U16": DTYPE_U16;
      case "U32": DTYPE_U32;
      case "U64": DTYPE_U64;
      case "U1": DTYPE_U1;
      case "F16": DTYPE_F16;
      case "F32": DTYPE_F32;
      case "F64": DTYPE_F64;
      default: -1;
    };
  }

  function structInitializer(expression:Expr):Null<Array<{name:String, value:Expr, dtype:Int}>> {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case EObjectDecl(fields):
        if (fields.length == 0) {
          Context.error("Quadrants struct local must have at least one field", expr.pos);
        }
        [for (field in fields) {name: field.field, value: field.expr, dtype: inferExpressionDType(field.expr)}];
      case ECall(callee, args):
        var path = callPath(callee, expr.pos);
        if (isStructFactoryPath(path)) {
          if (args.length % 2 != 0 || args.length == 0) {
            Context.error("Quadrants Struct.ofN expects field-name/value pairs", expr.pos);
          }
          [for (i in 0...(Std.int(args.length / 2))) {
            var nameExpr = stripNoCasts(args[i * 2]);
            var fieldName = switch (nameExpr.expr) {
              case EConst(CString(value, _)): value;
              default: Context.error("Quadrants Struct field name must be a string literal", nameExpr.pos);
            };
            var value = args[i * 2 + 1];
            {name: fieldName, value: value, dtype: inferExpressionDType(value)};
          }];
        } else {
          null;
        }
      default:
        null;
    };
  }

  function isStructFactoryPath(path:String):Bool {
    var prefix = "Struct.of";
    var qualifiedPrefix = "quadrants.Struct.of";
    var suffix = if (path.indexOf(prefix) == 0) {
      path.substr(prefix.length);
    } else if (path.indexOf(qualifiedPrefix) == 0) {
      path.substr(qualifiedPrefix.length);
    } else {
      "";
    };
    if (suffix.length == 0) {
      return false;
    }
    for (i in 0...suffix.length) {
      var code = suffix.charCodeAt(i);
      if (code < "0".code || code > "9".code) {
        return false;
      }
    }
    return true;
  }

  function encodeStructResourceLoadDeclaration(name:String,
      pos:Position,
      access:{resource:StructResourceInfo, indices:Array<Expr>},
      writer:ByteWriter):Int {
    if (paramIds.exists(name) || structResources.exists(name)) {
      Context.error('Quadrants struct local ${name} shadows a kernel parameter', pos);
    }
    if (currentScope().exists(name) || currentVectorScope().exists(name) || currentMatrixScope().exists(name) || currentStructScope().exists(name)) {
      Context.error('Duplicate Quadrants local variable ${name}', pos);
    }
    var structFields = new Map<String, StructFieldInfo>();
    var fieldOrder:Array<String> = [];
    var count = 0;
    for (fieldName in access.resource.order) {
      var member = access.resource.members.get(fieldName);
      if (member.lanes != 1) {
        Context.error("Quadrants whole-struct vector/matrix member load currently requires explicit scalar lane lowering", pos);
      }
      var localId = declareLocal(uniqueLocalName('__qd_struct_${name}_${fieldName}'), pos, true, member.dtype);
      structFields[fieldName] = {localId: localId, dtype: member.dtype};
      fieldOrder.push(fieldName);
      writer.u8(STMT_ASSIGN);
      writer.u8(EXPR_LOCAL_LOAD);
      writer.u32(localId);
      encodeStructMemberLoad({resource: access.resource, member: member, indices: access.indices}, writer, pos);
      count++;
    }
    currentStructScope()[name] = {fields: structFields, order: fieldOrder};
    return count;
  }

  function encodeStructDeclaration(name:String, pos:Position, fields:Array<{name:String, value:Expr, dtype:Int}>, writer:ByteWriter):Int {
    if (paramIds.exists(name) || structResources.exists(name)) {
      Context.error('Quadrants struct local ${name} shadows a kernel parameter', pos);
    }
    if (currentScope().exists(name) || currentVectorScope().exists(name) || currentMatrixScope().exists(name) || currentStructScope().exists(name)) {
      Context.error('Duplicate Quadrants local variable ${name}', pos);
    }
    var structFields = new Map<String, StructFieldInfo>();
    var fieldOrder:Array<String> = [];
    var statementCount = 0;
    for (field in fields) {
      if (structFields.exists(field.name)) {
        Context.error('Duplicate Quadrants struct field ${field.name}', pos);
      }
      var nestedName = directStructName(field.value);
      if (nestedName != null) {
        var nested = lookupStruct(nestedName);
        for (nestedFieldName in nested.order) {
          var fullName = field.name + "." + nestedFieldName;
          if (structFields.exists(fullName)) {
            Context.error('Duplicate Quadrants struct field ${fullName}', pos);
          }
          structFields[fullName] = nested.fields.get(nestedFieldName);
          fieldOrder.push(fullName);
        }
      } else {
        var localId = declareLocal(uniqueLocalName('__qd_struct_${name}_${field.name}'), pos, true, field.dtype);
        structFields[field.name] = {localId: localId, dtype: field.dtype};
        fieldOrder.push(field.name);
        writer.u8(STMT_ASSIGN);
        writer.u8(EXPR_LOCAL_LOAD);
        writer.u32(localId);
        encodeExpressionWithExpectedDType(field.value, field.dtype, writer);
        statementCount++;
      }
    }
    currentStructScope()[name] = {fields: structFields, order: fieldOrder};
    return statementCount;
  }

  function directStructName(expression:Expr):Null<String> {
    return switch (stripNoCasts(expression).expr) {
      case EConst(CIdent(name)) if (lookupStruct(name) != null): name;
      default: null;
    };
  }

  function structFieldPath(expression:Expr):Null<{structName:String, fieldName:String}> {
    return switch (stripNoCasts(expression).expr) {
      case EField(base, field):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (lookupStruct(name) != null):
            {structName: name, fieldName: field};
          case EField(_, _):
            var parent = structFieldPath(base);
            parent == null ? null : {structName: parent.structName, fieldName: parent.fieldName + "." + field};
          default:
            null;
        }
      default:
        null;
    };
  }

  function structFieldLocalId(expression:Expr):Null<Int> {
    var path = structFieldPath(expression);
    if (path == null) {
      return null;
    }
    var struct = lookupStruct(path.structName);
    var info = struct.fields.get(path.fieldName);
    if (info == null) {
      Context.error('Quadrants struct ${path.structName} has no field ${path.fieldName}', expression.pos);
    }
    return info.localId;
  }

  function structFieldDType(expression:Expr):Null<Int> {
    var path = structFieldPath(expression);
    if (path == null) {
      return null;
    }
    var struct = lookupStruct(path.structName);
    var info = struct.fields.get(path.fieldName);
    if (info == null) {
      Context.error('Quadrants struct ${path.structName} has no field ${path.fieldName}', expression.pos);
    }
    return info.dtype;
  }

  function encodeStructFieldAccess(expression:Expr, writer:ByteWriter):Bool {
    var localId = structFieldLocalId(expression);
    if (localId == null) {
      return false;
    }
    writer.u8(EXPR_LOCAL_LOAD);
    writer.u32(localId);
    return true;
  }

  function encodeMatrixDeclaration(name:String, pos:Position, init:MatrixInitInfo, writer:ByteWriter):Int {
    if (paramIds.exists(name)) {
      Context.error('Quadrants matrix local ${name} shadows a kernel parameter', pos);
    }
    if (currentScope().exists(name) || currentVectorScope().exists(name) || currentMatrixScope().exists(name) || currentStructScope().exists(name)) {
      Context.error('Duplicate Quadrants local variable ${name}', pos);
    }
    var localIds:Array<Int> = [];
    for (i in 0...init.values.length) {
      localIds.push(declareLocal(uniqueLocalName('__qd_mat_${name}_${i}'), pos, true, init.dtype));
    }
    currentMatrixScope()[name] = {localIds: localIds, rows: init.rows, cols: init.cols, dtype: init.dtype};
    var count = localIds.length;
    for (i in 0...localIds.length) {
      var valueExpr = init.values[i];
      var inlineCall = inlineFunctionCall(valueExpr);
      if (inlineCall != null) {
        var result = emitInlineFunctionToTemp(inlineCall.info, inlineCall.args, writer, valueExpr.pos);
        count += result.count;
        valueExpr = localLoadExpr(result.localId);
      }
      writer.u8(STMT_ASSIGN);
      writer.u8(EXPR_LOCAL_LOAD);
      writer.u32(localIds[i]);
      encodeExpressionWithExpectedDType(valueExpr, init.dtype, writer);
    }
    return count;
  }

  function matrixInitializer(expression:Expr):Null<MatrixInitInfo> {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case ECall(callee, args):
        var inlineCall = inlineFunctionCall(expr);
        if (inlineCall != null) {
          beginInlineFunctionScope(inlineCall.info, inlineCall.args, expr.pos);
          var returned = inlineFunctionReturnExpressionOrNull(inlineCall.info);
          var init = returned == null ? null : matrixInitializer(strip(returned));
          if (init != null) {
            init = {values: [for (value in init.values) substituteInlineArgs(value)], rows: init.rows, cols: init.cols, dtype: init.dtype};
          }
          finishInlineFunctionCall();
          if (init != null) return init;
        }
        var ctor = matrixConstructorInitializer(callee, args, expr.pos);
        if (ctor != null) return ctor;
        return matrixCallInitializer(callee, args, expr.pos);
      case EBinop(op, lhs, rhs):
        var lhsName = directMatrixName(lhs);
        var rhsName = directMatrixName(rhs);
        if (lhsName == null || rhsName == null) return null;
        var lhsMatrix = lookupMatrix(lhsName);
        var rhsMatrix = lookupMatrix(rhsName);
        if (lhsMatrix.rows != rhsMatrix.rows || lhsMatrix.cols != rhsMatrix.cols) {
          Context.error("Quadrants matrix elementwise operation requires equal shapes", expr.pos);
        }
        var dtype = promoteDType(lhsMatrix.dtype, rhsMatrix.dtype);
        var values:Array<Expr> = [];
        for (row in 0...lhsMatrix.rows) {
          for (col in 0...lhsMatrix.cols) {
            values.push(binaryExpr(op, matrixElementExpr(lhsName, row, col, expr.pos), matrixElementExpr(rhsName, row, col, expr.pos), expr.pos));
          }
        }
        return {values: values, rows: lhsMatrix.rows, cols: lhsMatrix.cols, dtype: dtype};
      default:
        return null;
    }
  }

  function matrixConstructorInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<MatrixInitInfo> {
    var compound = compoundMatrixReadInitializer(callee, args, pos);
    if (compound != null) return compound;
    var path = callPath(callee, pos);
    var packed = packedMatrixReadInitializer(path, args, pos);
    if (packed != null) return packed;
    if (path == "Matrix.ofArray" || path == "quadrants.Matrix.ofArray") {
      if (args.length != 3) {
        Context.error("Quadrants Matrix.ofArray expects rows, cols, and an array literal", pos);
      }
      var rows = staticIntLiteral(args[0], args[0].pos);
      var cols = staticIntLiteral(args[1], args[1].pos);
      if (rows <= 0 || cols <= 0) {
        Context.error("Quadrants Matrix.ofArray dimensions must be positive integer literals", pos);
      }
      var values = switch (stripNoCasts(args[2]).expr) {
        case EArrayDecl(values): values;
        default: Context.error("Quadrants Matrix.ofArray kernel initializer expects an array literal", args[2].pos);
      };
      if (values.length != rows * cols) {
        Context.error("Quadrants Matrix.ofArray value count must equal rows * cols", args[2].pos);
      }
      return {values: values, rows: rows, cols: cols, dtype: inferVectorValuesDType(values)};
    }
    var parts = path.split(".");
    if (parts.length < 2) return null;
    var typeName = parts[parts.length - 2];
    var method = parts[parts.length - 1];
    var dim = switch (typeName) {
      case "Mat2": 2;
      case "Mat3": 3;
      case "Mat4": 4;
      default: -1;
    };
    if (dim < 0) return null;
    var expected = dim * dim;
    if (args.length != expected) {
      Context.error('Quadrants ${typeName}.${method} expects ${expected} row-major arguments', pos);
    }
    return {values: args, rows: dim, cols: dim, dtype: vectorFactoryDType(method, pos)};
  }

  function compoundMatrixReadInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<MatrixInitInfo> {
    return switch (strip(callee).expr) {
      case EField(base, method):
        var dim = compoundMatrixDim(method, "readMat");
        if (dim < 0) {
          null;
        } else {
          if (args.length != 1) {
            Context.error("Quadrants compound matrix read expects one index", pos);
          }
          {values: packedReadValues(base, args[0], dim * dim, pos), rows: dim, cols: dim, dtype: arrayBaseDType(base, pos)};
        }
      default:
        null;
    };
  }

  function packedMatrixReadInitializer(path:String, args:Array<Expr>, pos:Position):Null<MatrixInitInfo> {
    var dim = -1;
    var dtype = DTYPE_I32;
    if (StringTools.endsWith(path, "PackedHelpers.readMat2I32")) {
      dim = 2;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readMat3I32")) {
      dim = 3;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readMat4I32")) {
      dim = 4;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readMat2F32")) {
      dim = 2;
      dtype = DTYPE_F32;
    }
    if (dim < 0) return null;
    if (args.length != 2) {
      Context.error("Quadrants packed matrix read helper expects storage and index", pos);
    }
    return {values: packedReadValues(args[0], args[1], dim * dim, pos), rows: dim, cols: dim, dtype: dtype};
  }

  function packedReadValues(storage:Expr, index:Expr, width:Int, pos:Position):Array<Expr> {
    return [for (component in 0...width) {
      var offset = binaryExpr(OpMult, index, intLiteralExpr(width, pos), pos);
      if (component != 0) {
        offset = binaryExpr(OpAdd, offset, intLiteralExpr(component, pos), pos);
      }
      {expr: ECall({expr: EField(storage, "kernelRead"), pos: pos}, [offset]), pos: pos};
    }];
  }

  function intLiteralExpr(value:Int, pos:Position):Expr {
    return {expr: EConst(CInt(Std.string(value), null)), pos: pos};
  }

  function matrixCallInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<MatrixInitInfo> {
    var staticInit = matrixStaticCallInitializer(callee, args, pos);
    if (staticInit != null) return staticInit;
    return switch (strip(callee).expr) {
      case EField(base, "transpose"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) null else {
          var matrix = lookupMatrix(name);
          var values:Array<Expr> = [];
          for (row in 0...matrix.cols) {
            for (col in 0...matrix.rows) {
              values.push(matrixElementExpr(name, col, row, pos));
            }
          }
          {values: values, rows: matrix.cols, cols: matrix.rows, dtype: matrix.dtype};
        }
      case EField(base, "matmul"):
        var lhs = directMatrixName(base);
        var rhs = args.length == 1 ? directMatrixName(args[0]) : null;
        if (lhs == null || rhs == null) null else {
          var lhsMatrix = lookupMatrix(lhs);
          var rhsMatrix = lookupMatrix(rhs);
          if (lhsMatrix.cols != rhsMatrix.rows) {
            Context.error("Quadrants matrix multiply shape mismatch", pos);
          }
          var dtype = promoteDType(lhsMatrix.dtype, rhsMatrix.dtype);
          var values:Array<Expr> = [];
          for (row in 0...lhsMatrix.rows) {
            for (col in 0...rhsMatrix.cols) {
              var sum = binaryExpr(OpMult, matrixElementExpr(lhs, row, 0, pos), matrixElementExpr(rhs, 0, col, pos), pos);
              for (k in 1...lhsMatrix.cols) {
                sum = binaryExpr(OpAdd, sum, binaryExpr(OpMult, matrixElementExpr(lhs, row, k, pos), matrixElementExpr(rhs, k, col, pos), pos), pos);
              }
              values.push(sum);
            }
          }
          {values: values, rows: lhsMatrix.rows, cols: rhsMatrix.cols, dtype: dtype};
        }
      case EField(base, "inverse"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) null else {
          var matrix = lookupMatrix(name);
          requireMatrixSquareSmall(matrix, "inverse", pos);
          if (matrix.dtype != DTYPE_F32 && matrix.dtype != DTYPE_F64) {
            Context.error("Quadrants matrix inverse in kernels requires F32 or F64 matrix values", pos);
          }
          var det = matrixDeterminantExpression(name, pos);
          var values:Array<Expr> = [];
          for (row in 0...matrix.rows) {
            for (col in 0...matrix.cols) {
              var cofactor = matrixCofactorExpression(name, col, row, pos);
              values.push(binaryExpr(OpDiv, cofactor, det, pos));
            }
          }
          {values: values, rows: matrix.rows, cols: matrix.cols, dtype: matrix.dtype};
        }
      case EField(base, "outer"):
        var lhs = directVectorName(base);
        var rhsInfo = args.length == 1 ? vectorValuesForExpression(args[0]) : null;
        if (lhs == null || rhsInfo == null) null else {
          var lhsVector = lookupVector(lhs);
          var dtype = promoteDType(lhsVector.dtype, rhsInfo.dtype);
          {values: [
            for (row in 0...lhsVector.localIds.length)
              for (col in 0...rhsInfo.values.length)
                binaryExpr(OpMult, vectorComponentExpr(lhs, row, pos), rhsInfo.values[col], pos)
          ], rows: lhsVector.localIds.length, cols: rhsInfo.values.length, dtype: dtype};
        }
      default:
        null;
    };
  }

  function matrixStaticCallInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<MatrixInitInfo> {
    var path = callPath(callee, pos);
    if (path == "Matrix.diag" || path == "quadrants.Matrix.diag") {
      if (args.length != 1) {
        Context.error("Quadrants Matrix.diag expects one vector argument", pos);
      }
      var vector = vectorValuesForExpression(args[0]);
      if (vector == null) return null;
      var values:Array<Expr> = [];
      for (row in 0...vector.values.length) {
        for (col in 0...vector.values.length) {
          values.push(row == col ? vector.values[row] : typedZeroExpr(vector.dtype, pos));
        }
      }
      return {values: values, rows: vector.values.length, cols: vector.values.length, dtype: vector.dtype};
    }
    if (path == "Matrix.outer" || path == "quadrants.Matrix.outer") {
      if (args.length != 2) {
        Context.error("Quadrants Matrix.outer expects two vector arguments", pos);
      }
      var lhs = vectorValuesForExpression(args[0]);
      var rhs = vectorValuesForExpression(args[1]);
      if (lhs == null || rhs == null) return null;
      var dtype = promoteDType(lhs.dtype, rhs.dtype);
      return {values: [
        for (row in 0...lhs.values.length)
          for (col in 0...rhs.values.length)
            binaryExpr(OpMult, lhs.values[row], rhs.values[col], pos)
      ], rows: lhs.values.length, cols: rhs.values.length, dtype: dtype};
    }
    return null;
  }

  function directMatrixName(expression:Expr):Null<String> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EConst(CIdent(name)):
        if (lookupMatrix(name) != null) {
          name;
        } else {
          var inlineArg = lookupInlineArg(name);
          inlineArg == null || directIdentifier(inlineArg) == name ? null : directMatrixName(inlineArg);
        }
      default: null;
    };
  }

  function matrixElementExpr(name:String, row:Int, col:Int, pos:Position):Expr {
    return {
      expr: EArray(
        {expr: EArray({expr: EConst(CIdent(name)), pos: pos}, {expr: EConst(CInt(Std.string(row), null)), pos: pos}), pos: pos},
        {expr: EConst(CInt(Std.string(col), null)), pos: pos}
      ),
      pos: pos
    };
  }

  function typedZeroExpr(dtype:Int, pos:Position):Expr {
    return intLiteralExpr(0, pos);
  }

  function vectorValuesForExpression(expression:Expr):Null<VectorInitInfo> {
    var name = directVectorName(expression);
    if (name != null) {
      var vector = lookupVector(name);
      return {values: [for (i in 0...vector.localIds.length) vectorComponentExpr(name, i, expression.pos)], dtype: vector.dtype};
    }
    return vectorInitializer(expression);
  }

  function requireMatrixSquareSmall(matrix:MatrixLocalInfo, operation:String, pos:Position):Void {
    if (matrix.rows != matrix.cols) {
      Context.error('Quadrants matrix ${operation} requires a square matrix', pos);
    }
    if (matrix.rows < 1 || matrix.rows > 4) {
      Context.error('Quadrants matrix ${operation} supports sizes 1x1 through 4x4', pos);
    }
  }

  function matrixValues(name:String, pos:Position):Array<Expr> {
    var matrix = lookupMatrix(name);
    return [for (row in 0...matrix.rows) for (col in 0...matrix.cols) matrixElementExpr(name, row, col, pos)];
  }

  function matrixTraceExpression(name:String, pos:Position):Expr {
    var matrix = lookupMatrix(name);
    requireMatrixSquareSmall(matrix, "trace", pos);
    var expr = matrixElementExpr(name, 0, 0, pos);
    for (i in 1...matrix.rows) {
      expr = binaryExpr(OpAdd, expr, matrixElementExpr(name, i, i, pos), pos);
    }
    return expr;
  }

  function matrixFrobeniusSquaredExpression(name:String, pos:Position):Expr {
    var matrix = lookupMatrix(name);
    var expr = binaryExpr(OpMult, matrixElementExpr(name, 0, 0, pos), matrixElementExpr(name, 0, 0, pos), pos);
    for (row in 0...matrix.rows) {
      for (col in 0...matrix.cols) {
        if (row != 0 || col != 0) {
          var value = matrixElementExpr(name, row, col, pos);
          expr = binaryExpr(OpAdd, expr, binaryExpr(OpMult, value, value, pos), pos);
        }
      }
    }
    return expr;
  }

  function matrixFrobeniusNormExpression(name:String, pos:Position):Expr {
    return {expr: ECall({expr: EConst(CIdent("sqrt")), pos: pos}, [matrixFrobeniusSquaredExpression(name, pos)]), pos: pos};
  }

  function matrixDeterminantExpression(name:String, pos:Position):Expr {
    var matrix = lookupMatrix(name);
    requireMatrixSquareSmall(matrix, "determinant", pos);
    return determinantExpressionFromValues(matrixValues(name, pos), matrix.rows, pos);
  }

  function matrixCofactorExpression(name:String, row:Int, col:Int, pos:Position):Expr {
    var matrix = lookupMatrix(name);
    if (matrix.rows == 1) {
      return typedOneExpr(matrix.dtype, pos);
    }
    var minor = minorValues(matrixValues(name, pos), matrix.rows, row, col);
    var value = determinantExpressionFromValues(minor, matrix.rows - 1, pos);
    return ((row + col) & 1) == 0 ? value : {expr: EUnop(OpNeg, false, value), pos: pos};
  }

  function determinantExpressionFromValues(values:Array<Expr>, dim:Int, pos:Position):Expr {
    if (dim == 1) {
      return values[0];
    }
    if (dim == 2) {
      return binaryExpr(OpSub,
        binaryExpr(OpMult, values[0], values[3], pos),
        binaryExpr(OpMult, values[1], values[2], pos),
        pos);
    }
    var result:Expr = null;
    for (col in 0...dim) {
      var term = binaryExpr(OpMult, values[col], determinantExpressionFromValues(minorValues(values, dim, 0, col), dim - 1, pos), pos);
      if (result == null) {
        result = (col & 1) == 0 ? term : {expr: EUnop(OpNeg, false, term), pos: pos};
      } else {
        result = (col & 1) == 0 ? binaryExpr(OpAdd, result, term, pos) : binaryExpr(OpSub, result, term, pos);
      }
    }
    return result;
  }

  function minorValues(values:Array<Expr>, dim:Int, skipRow:Int, skipCol:Int):Array<Expr> {
    var out:Array<Expr> = [];
    for (row in 0...dim) {
      if (row == skipRow) continue;
      for (col in 0...dim) {
        if (col != skipCol) out.push(values[row * dim + col]);
      }
    }
    return out;
  }

  function typedOneExpr(dtype:Int, pos:Position):Expr {
    return intLiteralExpr(1, pos);
  }

  function matrixElementLocalId(expression:Expr):Null<Int> {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case EArray(base, index):
        switch (stripNoCasts(base).expr) {
          case EArray(matrixBase, rowExpr):
            var name = directMatrixName(matrixBase);
            if (name == null) return null;
            var matrix = lookupMatrix(name);
            var row = constantIndex(rowExpr, rowExpr.pos);
            var col = constantIndex(index, index.pos);
            if (row < 0 || row >= matrix.rows || col < 0 || col >= matrix.cols) {
              Context.error('Quadrants matrix ${name} index is out of range', expr.pos);
            }
            return matrix.localIds[row * matrix.cols + col];
          default:
            var name = directMatrixName(base);
            if (name == null) return null;
            var matrix = lookupMatrix(name);
            var flatIndex = constantIndex(index, index.pos);
            if (flatIndex < 0 || flatIndex >= matrix.localIds.length) {
              Context.error('Quadrants matrix ${name} index is out of range', index.pos);
            }
            return matrix.localIds[flatIndex];
        }
      default:
        return null;
    }
  }

  function encodeMatrixAccess(expression:Expr, writer:ByteWriter):Bool {
    var localId = matrixElementLocalId(expression);
    if (localId == null) {
      return false;
    }
    writer.u8(EXPR_LOCAL_LOAD);
    writer.u32(localId);
    return true;
  }

  function encodeVectorDeclaration(name:String, pos:Position, init:VectorInitInfo, writer:ByteWriter):Int {
    if (paramIds.exists(name)) {
      Context.error('Quadrants vector local ${name} shadows a kernel parameter', pos);
    }
    if (currentScope().exists(name) || currentVectorScope().exists(name) || currentMatrixScope().exists(name) || currentStructScope().exists(name)) {
      Context.error('Duplicate Quadrants local variable ${name}', pos);
    }
    var localIds:Array<Int> = [];
    for (i in 0...init.values.length) {
      localIds.push(declareLocal(uniqueLocalName('__qd_vec_${name}_${i}'), pos, true, init.dtype));
    }
    currentVectorScope()[name] = {localIds: localIds, dtype: init.dtype};
    var count = localIds.length;
    for (i in 0...localIds.length) {
      var valueExpr = init.values[i];
      var inlineCall = inlineFunctionCall(valueExpr);
      if (inlineCall != null) {
        var result = emitInlineFunctionToTemp(inlineCall.info, inlineCall.args, writer, valueExpr.pos);
        count += result.count;
        valueExpr = localLoadExpr(result.localId);
      }
      writer.u8(STMT_ASSIGN);
      writer.u8(EXPR_LOCAL_LOAD);
      writer.u32(localIds[i]);
      encodeExpressionWithExpectedDType(valueExpr, init.dtype, writer);
    }
    return count;
  }

  function vectorInitializer(expression:Expr):Null<VectorInitInfo> {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case ECall(callee, args):
        var inlineCall = inlineFunctionCall(expr);
        if (inlineCall != null) {
          beginInlineFunctionScope(inlineCall.info, inlineCall.args, expr.pos);
          var returned = inlineFunctionReturnExpressionOrNull(inlineCall.info);
          var init = returned == null ? null : vectorInitializer(strip(returned));
          if (init != null) {
            init = {values: [for (value in init.values) substituteInlineArgs(value)], dtype: init.dtype};
          }
          finishInlineFunctionCall();
          if (init != null) return init;
        }
        var ctor = vectorConstructorInitializer(callee, args, expr.pos);
        if (ctor != null) return ctor;
        return vectorCallInitializer(callee, args, expr.pos);
      case EBinop(op, lhs, rhs):
        var lhsName = directVectorName(lhs);
        var rhsName = directVectorName(rhs);
        if (lhsName == null || rhsName == null) return null;
        var lhsVector = lookupVector(lhsName);
        var rhsVector = lookupVector(rhsName);
        if (lhsVector.localIds.length != rhsVector.localIds.length) {
          Context.error("Quadrants vector elementwise operation requires equal lengths", expr.pos);
        }
        var dtype = promoteDType(lhsVector.dtype, rhsVector.dtype);
        return {values: [for (i in 0...lhsVector.localIds.length) binaryExpr(op, vectorComponentExpr(lhsName, i, expr.pos), vectorComponentExpr(rhsName, i, expr.pos), expr.pos)], dtype: dtype};
      case EField(base, field):
        var name = directVectorName(base);
        if (name == null) return null;
        var indices = swizzleIndices(field);
        if (indices == null) return null;
        var vector = lookupVector(name);
        for (dim in indices) {
          if (dim >= vector.localIds.length) {
            Context.error('Quadrants vector ${name} swizzle ${field} is out of range', expr.pos);
          }
        }
        return {values: [for (dim in indices) vectorComponentExpr(name, dim, expr.pos)], dtype: vector.dtype};
      case EBlock(expressions):
        var values = vectorValuesFromLoweredConstructorBlock(expressions);
        if (values == null) return null;
        return {values: values, dtype: inferVectorValuesDType(values)};
      default:
        return null;
    }
  }

  function vectorValuesFromLoweredConstructorBlock(expressions:Array<Expr>):Null<Array<Expr>> {
    for (expression in expressions) {
      switch (strip(expression).expr) {
        case EVars(vars):
          for (variable in vars) {
            if (variable.name == "values" && variable.expr != null) {
              switch (stripNoCasts(variable.expr).expr) {
                case EArrayDecl(values):
                  if (values.length > 0 && values.length <= 4) {
                    return [for (value in values) substituteInlineArgs(value)];
                  }
                default:
              }
            }
          }
        default:
      }
    }
    return null;
  }

  function vectorConstructorInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<VectorInitInfo> {
    var compound = compoundVectorReadInitializer(callee, args, pos);
    if (compound != null) return compound;
    var path = callPath(callee, pos);
    var packed = packedVectorReadInitializer(path, args, pos);
    if (packed != null) return packed;
    if (path == "Vector.ofArray" || path == "quadrants.Vector.ofArray") {
      if (args.length != 1) {
        Context.error("Quadrants Vector.ofArray expects one array literal", pos);
      }
      var values = switch (stripNoCasts(args[0]).expr) {
        case EArrayDecl(values): values;
        default: Context.error("Quadrants Vector.ofArray kernel initializer expects an array literal", args[0].pos);
      };
      if (values.length == 0 || values.length > 4) {
        Context.error("Quadrants kernel vectors support one to four elements", args[0].pos);
      }
      return {values: values, dtype: inferVectorValuesDType(values)};
    }
    var parts = path.split(".");
    if (parts.length < 2) return null;
    var typeName = parts[parts.length - 2];
    var method = parts[parts.length - 1];
    var dim = switch (typeName) {
      case "Vec2": 2;
      case "Vec3": 3;
      case "Vec4": 4;
      default: -1;
    };
    if (dim < 0) return null;
    if (args.length != dim) {
      Context.error('Quadrants ${typeName}.${method} expects ${dim} arguments', pos);
    }
    return {values: args, dtype: vectorFactoryDType(method, pos)};
  }

  function compoundVectorReadInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<VectorInitInfo> {
    return switch (strip(callee).expr) {
      case EField(base, method):
        var width = compoundVectorWidth(method, "readVec");
        if (width < 0) {
          null;
        } else {
          if (args.length != 1) {
            Context.error("Quadrants compound vector read expects one index", pos);
          }
          {values: packedReadValues(base, args[0], width, pos), dtype: arrayBaseDType(base, pos)};
        }
      default:
        null;
    };
  }

  function packedVectorReadInitializer(path:String, args:Array<Expr>, pos:Position):Null<VectorInitInfo> {
    var width = -1;
    var dtype = DTYPE_I32;
    if (StringTools.endsWith(path, "PackedHelpers.readVec2I32")) {
      width = 2;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readVec3I32")) {
      width = 3;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readVec4I32")) {
      width = 4;
      dtype = DTYPE_I32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readVec2F32")) {
      width = 2;
      dtype = DTYPE_F32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readVec3F32")) {
      width = 3;
      dtype = DTYPE_F32;
    } else if (StringTools.endsWith(path, "PackedHelpers.readVec4F32")) {
      width = 4;
      dtype = DTYPE_F32;
    }
    if (width < 0) return null;
    if (args.length != 2) {
      Context.error("Quadrants packed vector read helper expects storage and index", pos);
    }
    return {values: packedReadValues(args[0], args[1], width, pos), dtype: dtype};
  }

  function vectorCallInitializer(callee:Expr, args:Array<Expr>, pos:Position):Null<VectorInitInfo> {
    return switch (strip(callee).expr) {
      case EField(base, "cross"):
        var lhs = directVectorName(base);
        var rhs = args.length == 1 ? directVectorName(args[0]) : null;
        if (lhs == null || rhs == null) null else {
          var lhsVector = lookupVector(lhs);
          var rhsVector = lookupVector(rhs);
          if (lhsVector.localIds.length != 3 || rhsVector.localIds.length != 3) {
            Context.error("Quadrants vector cross product requires two 3D vectors", pos);
          }
          var dtype = promoteDType(lhsVector.dtype, rhsVector.dtype);
          var ax = vectorComponentExpr(lhs, 0, pos);
          var ay = vectorComponentExpr(lhs, 1, pos);
          var az = vectorComponentExpr(lhs, 2, pos);
          var bx = vectorComponentExpr(rhs, 0, pos);
          var by = vectorComponentExpr(rhs, 1, pos);
          var bz = vectorComponentExpr(rhs, 2, pos);
          {values: [
            binaryExpr(OpSub, binaryExpr(OpMult, ay, bz, pos), binaryExpr(OpMult, az, by, pos), pos),
            binaryExpr(OpSub, binaryExpr(OpMult, az, bx, pos), binaryExpr(OpMult, ax, bz, pos), pos),
            binaryExpr(OpSub, binaryExpr(OpMult, ax, by, pos), binaryExpr(OpMult, ay, bx, pos), pos),
          ], dtype: dtype};
        }
      case EField(base, "normalized"):
        var name = directVectorName(base);
        if (name == null || args.length != 0) null else {
          var vector = lookupVector(name);
          var norm = {expr: ECall({expr: EField({expr: EConst(CIdent(name)), pos: pos}, "norm"), pos: pos}, []), pos: pos};
          {values: [for (i in 0...vector.localIds.length) binaryExpr(OpDiv, vectorComponentExpr(name, i, pos), norm, pos)], dtype: DTYPE_F32};
        }
      case EField(base, "diagonal"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) null else {
          var matrix = lookupMatrix(name);
          requireMatrixSquareSmall(matrix, "diagonal", pos);
          {values: [for (i in 0...matrix.rows) matrixElementExpr(name, i, i, pos)], dtype: matrix.dtype};
        }
      case EField(base, "matvec") | EField(base, "multiplyVector"):
        var matrixName = directMatrixName(base);
        var vectorInfo = args.length == 1 ? vectorValuesForExpression(args[0]) : null;
        if (matrixName == null || vectorInfo == null) null else {
          var matrix = lookupMatrix(matrixName);
          if (matrix.cols != vectorInfo.values.length) {
            Context.error("Quadrants matrix-vector multiply shape mismatch", pos);
          }
          var dtype = promoteDType(matrix.dtype, vectorInfo.dtype);
          {values: [
            for (row in 0...matrix.rows) {
              var sum = binaryExpr(OpMult, matrixElementExpr(matrixName, row, 0, pos), vectorInfo.values[0], pos);
              for (col in 1...matrix.cols) {
                sum = binaryExpr(OpAdd, sum, binaryExpr(OpMult, matrixElementExpr(matrixName, row, col, pos), vectorInfo.values[col], pos), pos);
              }
              sum;
            }
          ], dtype: dtype};
        }
      default:
        null;
    };
  }

  function inferVectorValuesDType(values:Array<Expr>):Int {
    var dtype = inferExpressionDType(values[0]);
    for (i in 1...values.length) {
      dtype = promoteDType(dtype, inferExpressionDType(values[i]));
    }
    return dtype;
  }

  function vectorFactoryDType(method:String, pos:Position):Int {
    return switch (method) {
      case "i32": DTYPE_I32;
      case "u32": DTYPE_U32;
      case "f16": DTYPE_F16;
      case "f32": DTYPE_F32;
      case "f64": DTYPE_F64;
      default: Context.error("Quadrants vector factory must be i32/u32/f16/f32/f64", pos);
    }
  }

  function directVectorName(expression:Expr):Null<String> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EConst(CIdent(name)):
        if (lookupVector(name) != null) {
          name;
        } else {
          var inlineArg = lookupInlineArg(name);
          inlineArg == null || directIdentifier(inlineArg) == name ? null : directVectorName(inlineArg);
        }
      case EField(base, "values"):
        directVectorName(base);
      default: null;
    };
  }

  function vectorComponentExpr(name:String, index:Int, pos:Position):Expr {
    return {expr: EArray({expr: EConst(CIdent(name)), pos: pos}, {expr: EConst(CInt(Std.string(index), null)), pos: pos}), pos: pos};
  }

  function binaryExpr(op:Binop, lhs:Expr, rhs:Expr, pos:Position):Expr {
    return {expr: EBinop(op, lhs, rhs), pos: pos};
  }

  function vectorFieldIndex(field:String):Int {
    return switch (field) {
      case "x" | "r" | "s": 0;
      case "y" | "g" | "t": 1;
      case "z" | "b" | "p": 2;
      case "w" | "a" | "q": 3;
      default: -1;
    }
  }

  function swizzleIndices(field:String):Null<Array<Int>> {
    if (field.length < 2 || field.length > 4) {
      return null;
    }
    for (group in ["xyzw", "rgba", "stpq"]) {
      var indices:Array<Int> = [];
      var matched = true;
      for (i in 0...field.length) {
        var componentIndex = group.indexOf(field.charAt(i));
        if (componentIndex < 0) {
          matched = false;
          break;
        }
        indices.push(componentIndex);
      }
      if (matched) {
        return indices;
      }
    }
    return null;
  }

  function vectorComponentLocalId(expression:Expr):Null<Int> {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case EArray(base, index):
        var name = directVectorName(base);
        if (name == null) return null;
        var vector = lookupVector(name);
        var dim = constantIndex(index, index.pos);
        if (dim < 0 || dim >= vector.localIds.length) {
          Context.error('Quadrants vector ${name} index is out of range', index.pos);
        }
        return vector.localIds[dim];
      case EField(base, field):
        var name = directVectorName(base);
        if (name == null) return null;
        var vector = lookupVector(name);
        if (field.length > 1 && swizzleIndices(field) != null) {
          return null;
        }
        var dim = vectorFieldIndex(field);
        if (dim < 0 || dim >= vector.localIds.length) {
          Context.error('Quadrants vector ${name} has no component ${field}', expr.pos);
        }
        return vector.localIds[dim];
      default:
        return null;
    }
  }

  function encodeVectorAccess(expression:Expr, writer:ByteWriter):Bool {
    var localId = vectorComponentLocalId(expression);
    if (localId == null) {
      return false;
    }
    writer.u8(EXPR_LOCAL_LOAD);
    writer.u32(localId);
    return true;
  }

  function vectorDotExpression(lhs:String, rhs:String, pos:Position):Expr {
    var lhsVector = lookupVector(lhs);
    var rhsVector = lookupVector(rhs);
    if (lhsVector.localIds.length != rhsVector.localIds.length) {
      Context.error("Quadrants vector dot product requires equal lengths", pos);
    }
    var expr = binaryExpr(OpMult, vectorComponentExpr(lhs, 0, pos), vectorComponentExpr(rhs, 0, pos), pos);
    for (i in 1...lhsVector.localIds.length) {
      expr = binaryExpr(OpAdd, expr, binaryExpr(OpMult, vectorComponentExpr(lhs, i, pos), vectorComponentExpr(rhs, i, pos), pos), pos);
    }
    return expr;
  }

  function encodeMatrixScalarCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Bool {
    switch (strip(callee).expr) {
      case EField(base, "get") | EField(base, "kernelGet"):
        var name = directMatrixName(base);
        if (name == null || args.length != 2) return false;
        var row = constantIndex(args[0], args[0].pos);
        var col = constantIndex(args[1], args[1].pos);
        var matrix = lookupMatrix(name);
        if (row < 0 || row >= matrix.rows || col < 0 || col >= matrix.cols) {
          Context.error('Quadrants matrix ${name}.get index is out of range', pos);
        }
        writer.u8(EXPR_LOCAL_LOAD);
        writer.u32(matrix.localIds[row * matrix.cols + col]);
        return true;
      case EField(base, "trace"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) return false;
        encodeMatrixScalarExpression(matrixTraceExpression(name, pos), lookupMatrix(name).dtype, writer);
        return true;
      case EField(base, "determinant"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) return false;
        encodeMatrixScalarExpression(matrixDeterminantExpression(name, pos), lookupMatrix(name).dtype, writer);
        return true;
      case EField(base, "frobeniusSquared"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) return false;
        encodeMatrixScalarExpression(matrixFrobeniusSquaredExpression(name, pos), lookupMatrix(name).dtype, writer);
        return true;
      case EField(base, "frobeniusNorm") | EField(base, "frobenius"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) return false;
        encodeMatrixScalarExpression(matrixFrobeniusNormExpression(name, pos), lookupMatrix(name).dtype, writer);
        return true;
      default:
        return false;
    }
  }

  function encodeMatrixScalarExpression(expression:Expr, sourceDType:Int, writer:ByteWriter):Void {
    var resultDType = sourceDType == DTYPE_F64 ? DTYPE_F64 : DTYPE_F32;
    if (sourceDType == resultDType) {
      encodeExpression(expression, writer);
      return;
    }
    writer.u8(EXPR_CAST);
    writer.u8(resultDType);
    encodeExpression(expression, writer);
  }

  function matrixScalarCallDType(callee:Expr, args:Array<Expr>):Null<Int> {
    return switch (strip(callee).expr) {
      case EField(base, "get") | EField(base, "kernelGet"):
        var name = directMatrixName(base);
        if (name == null || args.length != 2) null else lookupMatrix(name).dtype;
      case EField(base, "trace") | EField(base, "determinant") | EField(base, "frobeniusSquared") | EField(base, "frobeniusNorm") | EField(base, "frobenius"):
        var name = directMatrixName(base);
        if (name == null || args.length != 0) null else {
          var dtype = lookupMatrix(name).dtype;
          (dtype == DTYPE_F64) ? DTYPE_F64 : DTYPE_F32;
        }
      default:
        null;
    };
  }

  function encodeVectorScalarCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Bool {
    switch (strip(callee).expr) {
      case EField(base, "dot"):
        var lhs = directVectorName(base);
        var rhs = args.length == 1 ? directVectorName(args[0]) : null;
        if (lhs == null || rhs == null) return false;
        encodeExpression(vectorDotExpression(lhs, rhs, pos), writer);
        return true;
      case EField(base, "norm"):
        var name = directVectorName(base);
        if (name == null || args.length != 0) return false;
        writer.u8(EXPR_SQRT);
        encodeExpression(vectorDotExpression(name, name, pos), writer);
        return true;
      default:
        return false;
    }
  }

  function vectorScalarCallDType(callee:Expr, args:Array<Expr>):Null<Int> {
    return switch (strip(callee).expr) {
      case EField(base, "dot"):
        var lhs = directVectorName(base);
        var rhs = args.length == 1 ? directVectorName(args[0]) : null;
        if (lhs == null || rhs == null) null else promoteDType(lookupVector(lhs).dtype, lookupVector(rhs).dtype);
      case EField(base, "norm"):
        directVectorName(base) == null ? null : DTYPE_F32;
      default:
        null;
    };
  }

  function encodeAssignment(lhs:Expr, rhs:Expr, writer:ByteWriter, pos:Position):Int {
    var inlineCall = inlineFunctionCall(rhs);
    var extraCount = 0;
    var valueExpr = rhs;
    if (inlineCall != null) {
      var result = emitInlineFunctionToTemp(inlineCall.info, inlineCall.args, writer, rhs.pos);
      extraCount = result.count;
      valueExpr = localLoadExpr(result.localId);
    }
    switch (strip(lhs).expr) {
      case EArray(_, _):
        var wholeAccess = structWholeAccess(lhs);
        var sourceStruct = directStructName(valueExpr);
        if (wholeAccess != null && sourceStruct != null) {
          var source = lookupStruct(sourceStruct);
          for (fieldName in wholeAccess.resource.order) {
            var member = wholeAccess.resource.members.get(fieldName);
            var sourceField = source.fields.get(fieldName);
            if (sourceField == null) {
              Context.error('Quadrants struct ${sourceStruct} has no field ${fieldName}', pos);
            }
            encodeStructMemberStore({resource: wholeAccess.resource, member: member, indices: wholeAccess.indices}, localLoadExpr(sourceField.localId), writer, pos);
          }
          extraCount += wholeAccess.resource.order.length - 1;
        } else {
          var matrixLocalId = matrixElementLocalId(lhs);
        if (matrixLocalId != null) {
          writer.u8(STMT_ASSIGN);
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(matrixLocalId);
          encodeExpressionWithExpectedDType(valueExpr, locals[matrixLocalId].dtype, writer);
        } else {
          var vectorLocalId = vectorComponentLocalId(lhs);
          if (vectorLocalId != null) {
            writer.u8(STMT_ASSIGN);
            writer.u8(EXPR_LOCAL_LOAD);
            writer.u32(vectorLocalId);
            encodeExpressionWithExpectedDType(valueExpr, locals[vectorLocalId].dtype, writer);
          } else {
            var access = collectArrayAccess(lhs);
            writer.u8(STMT_STORE_INDEX);
            encodeArrayBase(access.base, writer, access.indices.length);
            writer.u32(access.indices.length);
            encodeArrayIndices(access.base, access.indices, writer);
            encodeExpression(valueExpr, writer);
          }
        }
      }
      case EConst(CIdent(name)):
        var localId = ensureLocalForAssignment(name, lhs.pos);
        writer.u8(STMT_ASSIGN);
        writer.u8(EXPR_LOCAL_LOAD);
        writer.u32(localId);
        encodeExpressionWithExpectedDType(valueExpr, locals[localId].dtype, writer);
      case EField(_, _):
        var memberAccess = structMemberAccess(lhs);
        if (memberAccess != null) {
          encodeStructMemberStore(memberAccess, valueExpr, writer, pos);
        } else {
          var swizzleCount = encodeSwizzleAssignment(lhs, valueExpr, writer, pos);
          if (swizzleCount != null) {
            return extraCount + swizzleCount;
          }
          var fieldLocalId = vectorComponentLocalId(lhs);
          if (fieldLocalId == null) {
            fieldLocalId = structFieldLocalId(lhs);
          }
          if (fieldLocalId == null) {
            Context.error("Quadrants HashLink only supports ndarray element, vector component, matrix element, struct field, or local variable assignments", pos);
          }
          writer.u8(STMT_ASSIGN);
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(fieldLocalId);
          encodeExpressionWithExpectedDType(valueExpr, locals[fieldLocalId].dtype, writer);
        }
      default:
        Context.error("Quadrants HashLink only supports ndarray element, vector component, matrix element, struct field, or local variable assignments", pos);
    }
    return extraCount + 1;
  }

  function encodeSwizzleAssignment(lhs:Expr, valueExpr:Expr, writer:ByteWriter, pos:Position):Null<Int> {
    switch (stripNoCasts(lhs).expr) {
      case EField(base, field):
        var name = directVectorName(base);
        if (name == null) {
          return null;
        }
        var indices = swizzleIndices(field);
        if (indices == null) {
          return null;
        }
        var vector = lookupVector(name);
        for (dim in indices) {
          if (dim >= vector.localIds.length) {
            Context.error('Quadrants vector ${name} swizzle ${field} is out of range', pos);
          }
        }
        var seen = new Map<Int, Bool>();
        for (dim in indices) {
          if (seen.exists(dim)) {
            Context.error("Quadrants swizzle assignment requires distinct components", pos);
          }
          seen[dim] = true;
        }
        var source = vectorValuesForExpression(valueExpr);
        if (source == null || source.values.length != indices.length) {
          Context.error('Quadrants swizzle assignment requires a ${indices.length}-component vector value', pos);
        }
        var tempIds:Array<Int> = [];
        for (i in 0...indices.length) {
          var tempId = declareLocal('__qdSwz${swizzleTempCounter++}', pos, true, vector.dtype);
          writer.u8(STMT_ASSIGN);
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(tempId);
          encodeExpressionWithExpectedDType(source.values[i], vector.dtype, writer);
          tempIds.push(tempId);
        }
        for (i in 0...indices.length) {
          writer.u8(STMT_ASSIGN);
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(vector.localIds[indices[i]]);
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(tempIds[i]);
        }
        return indices.length * 2;
      default:
        return null;
    }
  }

  function encodeCompoundAssignment(op:Binop, lhs:Expr, rhs:Expr, writer:ByteWriter, pos:Position):Int {
    switch (strip(lhs).expr) {
      case EArray(_, _) if (atomicStatementOpcode(op) != null):
        var access = collectArrayAccess(lhs);
        writer.u8(atomicStatementOpcode(op));
        encodeArrayBase(access.base, writer, access.indices.length);
        writer.u32(access.indices.length);
        encodeArrayIndices(access.base, access.indices, writer);
        encodeExpression(rhs, writer);
        return 1;
      default:
        return encodeAssignment(lhs, {expr: EBinop(op, lhs, rhs), pos: pos}, writer, pos);
    }
  }

  function encodeExpression(expression:Expr, writer:ByteWriter):Void {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case EConst(CInt(value, _)):
        var parsed = Std.parseInt(value);
        if (parsed == null) {
          Context.error('Invalid i32 literal ${value}', expr.pos);
        }
        writer.u8(EXPR_CONST_I32);
        writer.i32(parsed);
      case EConst(CFloat(value, _)):
        var parsed = Std.parseFloat(value);
        if (Math.isNaN(parsed)) {
          Context.error('Invalid f64 literal ${value}', expr.pos);
        }
        writer.u8(EXPR_CONST_F64);
        writer.f64(parsed);
      case EConst(CIdent("true")):
        writer.u8(EXPR_CONST_BOOL);
        writer.u8(1);
      case EConst(CIdent("false")):
        writer.u8(EXPR_CONST_BOOL);
        writer.u8(0);
      case EConst(CIdent(name)):
        var inlineArg = lookupInlineArg(name);
        if (inlineArg != null && directIdentifier(inlineArg) != name) {
          encodeExpression(inlineArg, writer);
        } else {
          var localId = lookupLocal(name);
          if (localId != null) {
            writer.u8(EXPR_LOCAL_LOAD);
            writer.u32(localId);
          } else {
            var paramId = paramIds.get(name);
            if (paramId == null) {
              Context.error('Unknown Quadrants kernel identifier ${name}', expr.pos);
            }
            markParamScalar(paramId, expr.pos);
            writer.u8(EXPR_ARG_LOAD);
            writer.u32(paramId);
          }
        }
      case EArray(_, _):
        if (!encodeMatrixAccess(expr, writer) && !encodeVectorAccess(expr, writer) && !encodeIndexVectorAccess(expr, writer)) {
          var access = collectArrayAccess(expr);
          writer.u8(EXPR_LOAD_INDEX);
          encodeArrayBase(access.base, writer, access.indices.length);
          writer.u32(access.indices.length);
          encodeArrayIndices(access.base, access.indices, writer);
        }
      case EBinop(op, lhs, rhs):
        writer.u8(binaryOpcode(op, expr.pos));
        encodeExpression(lhs, writer);
        encodeExpression(rhs, writer);
      case EUnop(op, _, operand):
        writer.u8(unaryOpcode(op, expr.pos));
        encodeExpression(operand, writer);
      case EField(_, _):
        var structMember = structMemberAccess(expr);
        if (structMember != null) {
          encodeStructMemberLoad(structMember, writer, expr.pos);
        } else if (!encodeFrexpFieldAccess(expr, writer) && !encodeVectorAccess(expr, writer) && !encodeStructFieldAccess(expr, writer)) {
          Context.error("Unsupported Quadrants HashLink kernel expression: " + new haxe.macro.Printer().printExpr(expr), expr.pos);
        }
      case ECall(callee, args):
        encodeCall(callee, args, writer, expr.pos);
      case ECast(inner, type), ECheckType(inner, type):
        var dtype = dtypeFromComplexType(type, expr.pos);
        if (!encodeTypedConstant(inner, dtype, writer, expr.pos)) {
          writer.u8(EXPR_CAST);
          writer.u8(dtype);
          encodeExpression(inner, writer);
        }
      case EIf(condition, ifExpr, elseExpr) if (elseExpr != null):
        writer.u8(EXPR_SELECT);
        encodeExpression(condition, writer);
        encodeExpression(ifExpr, writer);
        encodeExpression(elseExpr, writer);
      case ETernary(condition, ifExpr, elseExpr):
        writer.u8(EXPR_SELECT);
        encodeExpression(condition, writer);
        encodeExpression(ifExpr, writer);
        encodeExpression(elseExpr, writer);
      default:
        Context.error("Unsupported Quadrants HashLink kernel expression: " + new haxe.macro.Printer().printExpr(expr), expr.pos);
    }
  }

  function encodeArrayBase(base:Expr, writer:ByteWriter, rank:Int):Void {
    var expr = strip(base);
    switch (expr.expr) {
      case EConst(CIdent(name)):
        var inlineArg = lookupInlineArg(name);
        if (inlineArg != null && directIdentifier(inlineArg) != name) {
          encodeArrayBase(inlineArg, writer, rank);
          return;
        }
        var localId = lookupLocal(name);
        if (localId != null && locals[localId].sharedSize > 0) {
          writer.u8(EXPR_LOCAL_LOAD);
          writer.u32(localId);
          return;
        }
        var paramId = paramIds.get(name);
        if (paramId == null) {
          Context.error('Quadrants ndarray ${name} is not a kernel parameter', expr.pos);
        }
        if (params[paramId].kind == PARAM_FIELD || params[paramId].kind == PARAM_MESH_ATTRIBUTE) {
          markParamField(paramId, rank, expr.pos);
        } else {
          markParamNdarray(paramId, rank, expr.pos);
        }
        writer.u8(EXPR_ARG_LOAD);
        writer.u32(paramId);
      default:
        Context.error("Quadrants HashLink only supports direct ndarray parameter or shared-array local indexing", expr.pos);
    }
  }

  function collectArrayAccess(expression:Expr):{base:Expr, indices:Array<Expr>} {
    var indices:Array<Expr> = [];
    var current = strip(expression);
    while (true) {
      switch (current.expr) {
        case EArray(base, index):
          indices.unshift(index);
          current = strip(base);
        default:
          if (indices.length == 0 || indices.length > 8) {
            Context.error("Quadrants ndarray index count is out of range", expression.pos);
          }
          return {base: current, indices: indices};
      }
    }
    throw "unreachable";
  }

  function structWholeAccess(expression:Expr):Null<{resource:StructResourceInfo, indices:Array<Expr>}> {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case EArray(_, _):
        var access = collectArrayAccess(expr);
        switch (stripNoCasts(access.base).expr) {
          case EConst(CIdent(name)):
            var resource = structResources.get(name);
            resource == null ? null : {resource: resource, indices: access.indices};
          default:
            null;
        }
      default:
        null;
    };
  }

  function structMemberAccess(expression:Expr):Null<{resource:StructResourceInfo, member:StructResourceMemberInfo, indices:Array<Expr>}> {
    var segments:Array<String> = [];
    var current = stripNoCasts(expression);
    while (true) {
      switch (current.expr) {
        case EField(base, field):
          segments.unshift(field);
          current = stripNoCasts(base);
        default:
          var whole = structWholeAccess(current);
          if (whole == null || segments.length == 0) {
            return null;
          }
          var fieldPath = segments.join(".");
          var member = whole.resource.members.get(fieldPath);
          if (member == null) {
            Context.error('Quadrants struct ${whole.resource.structName} has no field ${fieldPath}', expression.pos);
          }
          return {resource: whole.resource, member: member, indices: whole.indices};
      }
    }
    return null;
  }

  function encodeStructMemberLoad(access:{resource:StructResourceInfo, member:StructResourceMemberInfo, indices:Array<Expr>}, writer:ByteWriter, pos:Position):Void {
    var rank = access.indices.length + (access.member.laneIndex >= 0 ? 1 : 0);
    if (access.resource.kind == PARAM_FIELD) {
      markParamField(access.member.paramId, rank, pos);
    } else {
      markParamNdarray(access.member.paramId, rank, pos);
    }
    writer.u8(EXPR_LOAD_INDEX);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(access.member.paramId);
    writer.u32(rank);
    for (index in access.indices) {
      encodeExpression(index, writer);
    }
    if (access.member.laneIndex >= 0) {
      writer.u8(EXPR_CONST_I32);
      writer.i32(access.member.laneIndex);
    }
  }

  function encodeStructMemberStore(access:{resource:StructResourceInfo, member:StructResourceMemberInfo, indices:Array<Expr>}, value:Expr, writer:ByteWriter, pos:Position):Void {
    var rank = access.indices.length + (access.member.laneIndex >= 0 ? 1 : 0);
    if (access.resource.kind == PARAM_FIELD) {
      markParamField(access.member.paramId, rank, pos);
    } else {
      markParamNdarray(access.member.paramId, rank, pos);
    }
    writer.u8(STMT_STORE_INDEX);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(access.member.paramId);
    writer.u32(rank);
    for (index in access.indices) {
      encodeExpression(index, writer);
    }
    if (access.member.laneIndex >= 0) {
      writer.u8(EXPR_CONST_I32);
      writer.i32(access.member.laneIndex);
    }
    encodeExpressionWithExpectedDType(value, access.member.dtype, writer);
  }

  function directIdentifier(expression:Expr):Null<String> {
    return switch (stripNoCasts(expression).expr) {
      case EConst(CIdent(name)): name;
      default: null;
    };
  }

  function bufferViewStartParamId(base:Expr):Null<Int> {
    var name = directIdentifier(base);
    return name == null ? null : bufferViewStartParamIds.get(name);
  }

  function encodeArrayIndices(base:Expr, indices:Array<Expr>, writer:ByteWriter):Void {
    var startParamId = bufferViewStartParamId(base);
    if (startParamId == null) {
      var clampParamId = clampBoundaryParamId(base);
      for (axis in 0...indices.length) {
        if (clampParamId != null) {
          encodeClampedIndex(clampParamId, axis, indices[axis], writer);
        } else {
          encodeExpression(indices[axis], writer);
        }
      }
      return;
    }
    if (indices.length != 1) {
      Context.error("Quadrants BufferView kernel indexing is one-dimensional", base.pos);
    }
    writer.u8(EXPR_BINARY_ADD);
    encodeExpression(indices[0], writer);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(startParamId);
  }

  function clampBoundaryParamId(base:Expr):Null<Int> {
    var name = directIdentifier(base);
    if (name == null || !clampBoundaryParams.exists(name)) {
      return null;
    }
    return paramIds.get(name);
  }

  function encodeClampedIndex(paramId:Int, axis:Int, index:Expr, writer:ByteWriter):Void {
    writer.u8(EXPR_MIN);
    writer.u8(EXPR_MAX);
    encodeExpression(index, writer);
    writer.u8(EXPR_CONST_I32);
    writer.i32(0);
    writer.u8(EXPR_BINARY_SUB);
    writer.u8(EXPR_SHAPE_AXIS);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(paramId);
    writer.u32(axis);
    writer.u8(EXPR_CONST_I32);
    writer.i32(1);
  }

  function encodeIndexVectorAccess(expression:Expr, writer:ByteWriter):Bool {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EArray(base, index):
        switch (strip(base).expr) {
          case EConst(CIdent(name)):
            var localIds = lookupIndexVector(name);
            if (localIds == null) {
              false;
            } else {
              var dim = constantIndex(index, index.pos);
              if (dim < 0 || dim >= localIds.length) {
                Context.error('Quadrants loop index vector ${name} dimension is out of range', index.pos);
              }
              writer.u8(EXPR_LOCAL_LOAD);
              writer.u32(localIds[dim]);
              true;
            }
          default:
            false;
        }
      default:
        false;
    };
  }

  function constantIndex(expression:Expr, pos:Position):Int {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EConst(CInt(value, _)):
        var parsed = Std.parseInt(value);
        if (parsed == null) {
          Context.error('Invalid integer index ${value}', expr.pos);
        }
        parsed;
      default:
        Context.error("Quadrants loop index vector dimension must be an integer literal", pos);
    };
  }

  function parseInt64Parts(value:String, pos:Position):{low:Int, high:Int} {
    var text = StringTools.replace(value, "_", "");
    var negative = false;
    if (StringTools.startsWith(text, "-")) {
      negative = true;
      text = text.substr(1);
    }
    var radix = 10;
    if (StringTools.startsWith(text, "0x") || StringTools.startsWith(text, "0X")) {
      radix = 16;
      text = text.substr(2);
    }
    if (text.length == 0) {
      Context.error('Invalid 64-bit literal ${value}', pos);
    }
    var acc:haxe.Int64 = 0;
    var base:haxe.Int64 = radix;
    for (i in 0...text.length) {
      var code = text.charCodeAt(i);
      var digit = if (code >= 48 && code <= 57) {
        code - 48;
      } else if (code >= 97 && code <= 102) {
        code - 97 + 10;
      } else if (code >= 65 && code <= 70) {
        code - 65 + 10;
      } else {
        -1;
      }
      if (digit < 0 || digit >= radix) {
        Context.error('Invalid 64-bit literal ${value}', pos);
      }
      acc = acc * base + digit;
    }
    if (negative) {
      acc = -acc;
    }
    return {low: acc.low, high: acc.high};
  }

  function encodeTypedConstant(expression:Expr, dtype:Int, writer:ByteWriter, pos:Position):Bool {
    var expr = strip(expression);
    switch (expr.expr) {
      case EConst(CIdent("true")) if (dtype == DTYPE_U1):
        writer.u8(EXPR_CONST_BOOL);
        writer.u8(1);
        return true;
      case EConst(CIdent("false")) if (dtype == DTYPE_U1):
        writer.u8(EXPR_CONST_BOOL);
        writer.u8(0);
        return true;
      case EConst(CInt(value, _)) if (dtype == DTYPE_I64 || dtype == DTYPE_U64):
        var parts = parseInt64Parts(value, expr.pos);
        writer.u8(dtype == DTYPE_I64 ? EXPR_CONST_I64 : EXPR_CONST_U64);
        writer.u64Parts(parts.low, parts.high);
        return true;
      case EConst(CInt(value, _)) if (dtype == DTYPE_F32 || dtype == DTYPE_F16):
        var parsed = Std.parseFloat(value);
        if (Math.isNaN(parsed)) {
          Context.error('Invalid f32 literal ${value}', expr.pos);
        }
        if (dtype == DTYPE_F32) {
          writer.u8(EXPR_CONST_F32);
        } else {
          writer.u8(EXPR_CAST);
          writer.u8(DTYPE_F16);
          writer.u8(EXPR_CONST_F32);
        }
        writer.f32(parsed);
        return true;
      case EConst(CFloat(value, _)) if (dtype == DTYPE_F32 || dtype == DTYPE_F16):
        var parsed = Std.parseFloat(value);
        if (Math.isNaN(parsed)) {
          Context.error('Invalid f32 literal ${value}', expr.pos);
        }
        if (dtype == DTYPE_F32) {
          writer.u8(EXPR_CONST_F32);
        } else {
          writer.u8(EXPR_CAST);
          writer.u8(DTYPE_F16);
          writer.u8(EXPR_CONST_F32);
        }
        writer.f32(parsed);
        return true;
      default:
        return false;
    }
  }

  function encodeExpressionWithExpectedDType(expression:Expr, dtype:Int, writer:ByteWriter):Void {
    if (!encodeTypedConstant(expression, dtype, writer, expression.pos)) {
      encodeExpression(expression, writer);
    }
  }

  function atomicStatementOpcode(op:Binop):Null<Int> {
    return switch (op) {
      case OpAdd: STMT_ATOMIC_ADD;
      case OpSub: STMT_ATOMIC_SUB;
      case OpMult: STMT_ATOMIC_MUL;
      case OpAnd: STMT_ATOMIC_AND;
      case OpOr: STMT_ATOMIC_OR;
      case OpXor: STMT_ATOMIC_XOR;
      default: null;
    };
  }

  function binaryOpcode(op:Binop, pos:Position):Int {
    return switch (op) {
      case OpAdd: EXPR_BINARY_ADD;
      case OpSub: EXPR_BINARY_SUB;
      case OpMult: EXPR_BINARY_MUL;
      case OpDiv: EXPR_BINARY_DIV;
      case OpMod: EXPR_BINARY_MOD;
      case OpEq: EXPR_CMP_EQ;
      case OpNotEq: EXPR_CMP_NE;
      case OpLt: EXPR_CMP_LT;
      case OpLte: EXPR_CMP_LE;
      case OpGt: EXPR_CMP_GT;
      case OpGte: EXPR_CMP_GE;
      case OpBoolAnd: EXPR_LOGIC_AND;
      case OpBoolOr: EXPR_LOGIC_OR;
      case OpAnd: EXPR_BIT_AND;
      case OpOr: EXPR_BIT_OR;
      case OpXor: EXPR_BIT_XOR;
      case OpShl: EXPR_SHL;
      case OpShr: EXPR_SAR;
      case OpUShr: EXPR_SHR;
      default: Context.error("Unsupported Quadrants HashLink binary operator", pos);
    }
  }

  function unaryOpcode(op:Unop, pos:Position):Int {
    return switch (op) {
      case OpNot: EXPR_LOGIC_NOT;
      case OpNeg: EXPR_UNARY_NEG;
      case OpNegBits: EXPR_BIT_NOT;
      default: Context.error("Unsupported Quadrants HashLink unary operator", pos);
    }
  }

  function encodeCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (encodeMatrixScalarCall(callee, args, writer, pos)) {
      return;
    }
    if (encodeVectorScalarCall(callee, args, writer, pos)) {
      return;
    }
    var name = callName(callee, pos);
    var path = callPath(callee, pos);
    var atomicOpcode = atomicExpressionOpcode(name);
    if (atomicOpcode != null) {
      encodeAtomicCall(name, atomicOpcode, args, writer, pos);
      return;
    }
    if (name == "atan") {
      encodeAtanCall(args, writer, pos);
      return;
    }
    if (path == "CompilerHints.assumeInRange" || path == "quadrants.CompilerHints.assumeInRange") {
      encodeAssumeInRangeCall(args, writer, pos);
      return;
    }
    if (isStaticValueCall(callee)) {
      if (args.length != 1) {
        Context.error("Quadrants Static.value expects one argument", pos);
      }
      encodeExpression(args[0], writer);
      return;
    }
    var quantReadEncoded = encodeQuantReadExpressionCall(callee, args, writer, pos);
    if (quantReadEncoded) {
      return;
    }
    var meshRelationEncoded = encodeMeshRelationExpressionCall(callee, args, writer, pos);
    if (meshRelationEncoded) {
      return;
    }
    var meshAttrRead = meshAttributeMethodTarget(callee, "read");
    if (meshAttrRead != null) {
      if (args.length != 1) {
        Context.error("Quadrants MeshAttribute.read(index) expects one argument in kernels", pos);
      }
      writer.u8(EXPR_LOAD_INDEX);
      encodeArrayBase(meshAttrRead, writer, 1);
      writer.u32(1);
      encodeArrayIndices(meshAttrRead, [args[0]], writer);
      return;
    }
    var internalOpcode = internalExpressionOpcode(path);
    var scalarReadBase = tensorMethodTarget(callee, "scalarRead");
    if (scalarReadBase == null && name == "scalarRead" && args.length == 1) {
      scalarReadBase = args[0];
      args = [];
    }
    var readMethodBase = tensorMethodTarget(callee, "read");
    if (readMethodBase == null) {
      readMethodBase = tensorMethodTarget(callee, "kernelRead");
    }
    if (readMethodBase == null && (name == "read" || name == "kernelRead") && args.length == 2) {
      readMethodBase = args[0];
      args = [args[1]];
    }
    var shapeMethodBase = shapeMethodTarget(callee);
    if (encodePackedMemberReadCall(path, args, writer, pos)) {
      return;
    }
    if (scalarReadBase != null) {
      if (args.length != 0) {
        Context.error("Quadrants HashLink Tensor.scalarRead() expects no arguments", pos);
      }
      writer.u8(EXPR_LOAD_INDEX);
      encodeArrayBase(scalarReadBase, writer, 0);
      writer.u32(0);
      encodeArrayIndices(scalarReadBase, [], writer);
      return;
    }
    var snodeExprEncoded = encodeSNodeExpressionCall(callee, args, writer, pos);
    if (snodeExprEncoded) {
      return;
    }
    if (readMethodBase != null) {
      if (args.length != 1) {
        Context.error("Quadrants HashLink Tensor.read(index) expects one argument", pos);
      }
      writer.u8(EXPR_LOAD_INDEX);
      encodeArrayBase(readMethodBase, writer, 1);
      writer.u32(1);
      encodeArrayIndices(readMethodBase, [args[0]], writer);
      return;
    }
    if (shapeMethodBase != null) {
      if (args.length != 1) {
        Context.error("Quadrants HashLink Tensor.shape(axis) expects one argument", pos);
      }
      encodeShapeCall([shapeMethodBase, args[0]], writer, pos);
      return;
    }
    if (internalOpcode != null) {
      encodeInternalExpressionCall(path, internalOpcode, args, writer, pos);
      return;
    }
    if (name == "threadIdx") {
      if (args.length != 0) {
        Context.error("Quadrants HashLink function threadIdx expects no arguments", pos);
      }
      writer.u8(EXPR_THREAD_IDX);
      return;
    }
    if (name == "shape") {
      encodeShapeCall(args, writer, pos);
      return;
    }
    if (name == "bitCast") {
      encodeBitCastCall(args, writer, pos);
      return;
    }
    if (name == "volatileLoad") {
      encodeVolatileLoadCall(args, writer, pos);
      return;
    }
    if (name == "rawDiv" || name == "rawMod") {
      encodeRawDivModCall(name, args, writer, pos);
      return;
    }
    if (name == "fnsU32") {
      encodeFnsU32Call(args, writer, pos);
      return;
    }
    if (name == "randnF32" || name == "randnF64") {
      encodeRandnCall(name, args, writer, pos);
      return;
    }
    if (frexpCallDType(name) != null) {
      Context.error('Quadrants HashLink ${name} returns a struct; assign it to a local and read .significand/.exponent, or read a field directly', pos);
    }
    if (name == "select") {
      encodeSelectCall(args, writer, pos);
      return;
    }
    if (name == "isnan" || name == "isinf") {
      encodeFloatingPredicateCall(name, args, writer, pos);
      return;
    }
    var randomDType = randomCallDType(name);
    if (randomDType != null) {
      if (args.length != 0) {
        Context.error('Quadrants HashLink function ${name} expects no arguments', pos);
      }
      writer.u8(EXPR_RAND);
      writer.u8(randomDType);
      return;
    }
    var opcode = builtinCallOpcode(name);
    if (opcode != null) {
      var arity = (opcode == EXPR_MIN || opcode == EXPR_MAX || opcode == EXPR_ATAN2 || opcode == EXPR_POW) ? 2 : 1;
      if (args.length != arity) {
        Context.error('Quadrants HashLink function ${name} expects ${arity} argument(s)', pos);
      }
      writer.u8(opcode);
      for (arg in args) {
        encodeExpression(arg, writer);
      }
      return;
    }
    var inlineFunction = functions.get(name);
    if (inlineFunction != null) {
      encodeInlineFunctionCall(inlineFunction, args, writer, pos);
      return;
    }
    Context.error('Unsupported Quadrants HashLink function call ${name}', pos);
  }

  function quantMethodTarget(callee:Expr, method:String):Null<String> {
    return switch (strip(callee).expr) {
      case EField(base, field) if (field == method):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (quantScaleParamIds.exists(name)): name;
          default: null;
        }
      default:
        null;
    };
  }

  function encodeQuantReadExpressionCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Bool {
    var name = quantMethodTarget(callee, "read");
    if (name == null) {
      return false;
    }
    if (args.length != 1) {
      Context.error("Quadrants QuantizedF32Tensor.read(index) expects one argument in kernels", pos);
    }
    writer.u8(EXPR_BINARY_DIV);
    writer.u8(EXPR_CAST);
    writer.u8(DTYPE_F32);
    writer.u8(EXPR_LOAD_INDEX);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(paramIds.get(name));
    writer.u32(1);
    encodeExpression(args[0], writer);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(quantScaleParamIds.get(name));
    return true;
  }

  function encodeQuantWriteStatement(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Null<Int> {
    var name = quantMethodTarget(callee, "write");
    if (name == null) {
      return null;
    }
    if (args.length != 2) {
      Context.error("Quadrants QuantizedF32Tensor.write(index, value) expects two arguments in kernels", pos);
    }
    writer.u8(STMT_STORE_INDEX);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(paramIds.get(name));
    writer.u32(1);
    encodeExpression(args[0], writer);
    writer.u8(EXPR_CAST);
    writer.u8(DTYPE_I32);
    writer.u8(EXPR_MIN);
    writer.u8(EXPR_MAX);
    writer.u8(EXPR_ROUND);
    writer.u8(EXPR_BINARY_MUL);
    encodeExpressionWithExpectedDType(args[1], DTYPE_F32, writer);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(quantScaleParamIds.get(name));
    writer.u8(EXPR_CAST);
    writer.u8(DTYPE_F32);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(quantMinParamIds.get(name));
    writer.u8(EXPR_CAST);
    writer.u8(DTYPE_F32);
    writer.u8(EXPR_ARG_LOAD);
    writer.u32(quantMaxParamIds.get(name));
    return 1;
  }

  function meshAttributeMethodTarget(callee:Expr, method:String):Null<Expr> {
    return switch (strip(callee).expr) {
      case EField(base, field) if (field == method):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshAttributeParamIds.exists(name)):
            base;
          default:
            null;
        }
      default:
        null;
    };
  }

  function meshRelationIndexConversion(method:String):Null<Int> {
    return switch (method) {
      case "sourceLocalToGlobal" | "targetLocalToGlobal" | "sourceIndexLocalToGlobal" | "targetIndexLocalToGlobal": 0;
      case "sourceLocalToReordered" | "targetLocalToReordered" | "sourceIndexLocalToReordered" | "targetIndexLocalToReordered": 1;
      case "sourceGlobalToReordered" | "targetGlobalToReordered": 2;
      default: null;
    };
  }

  function meshRelationIndexSelector(method:String):Int {
    return StringTools.startsWith(method, "target") ? 1 : 0;
  }

  function meshRelationCallDType(callee:Expr, args:Array<Expr>, pos:Position):Null<Int> {
    return switch (strip(callee).expr) {
      case EField(base, method) if (meshRelationIndexConversion(method) != null):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshRelationSizeParamIds.exists(name)):
            if (args.length != 1) {
              Context.error('Quadrants MeshRelation.${method}(index) expects one integer argument in kernels', pos);
            }
            DTYPE_I32;
          default:
            null;
        }
      case EField(base, "get"):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshRelationSizeParamIds.exists(name)):
            if (args.length != 2) {
              Context.error("Quadrants MeshRelation.get(source, neighborIndex) expects two integer arguments in kernels", pos);
            }
            DTYPE_I32;
          default:
            null;
        }
      case EField(base, "size"):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshRelationSizeParamIds.exists(name)):
            if (args.length != 1) {
              Context.error("Quadrants MeshRelation.size(source) expects one integer argument in kernels", pos);
            }
            DTYPE_I32;
          default:
            null;
        }
      default:
        null;
    };
  }

  function encodeMeshRelationExpressionCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Bool {
    return switch (strip(callee).expr) {
      case EField(base, method) if (meshRelationIndexConversion(method) != null):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshRelationSizeParamIds.exists(name)):
            if (args.length != 1) {
              Context.error('Quadrants MeshRelation.${method}(index) expects one integer argument in kernels', pos);
            }
            writer.u8(EXPR_MESH_INDEX_CONVERT);
            writer.u32(paramIds.get(name));
            writer.u8(meshRelationIndexSelector(method));
            writer.u8(meshRelationIndexConversion(method));
            encodeExpression(args[0], writer);
            true;
          default:
            false;
        }
      case EField(base, "get"):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshRelationSizeParamIds.exists(name)):
            if (args.length != 2) {
              Context.error("Quadrants MeshRelation.get(source, neighborIndex) expects two integer arguments in kernels", pos);
            }
            var paramId = paramIds.get(name);
            writer.u8(EXPR_MESH_RELATION_GET);
            writer.u32(paramId);
            encodeExpression(args[0], writer);
            encodeExpression(args[1], writer);
            true;
          default:
            false;
        }
      case EField(base, "size"):
        switch (stripNoCasts(base).expr) {
          case EConst(CIdent(name)) if (meshRelationSizeParamIds.exists(name)):
            if (args.length != 1) {
              Context.error("Quadrants MeshRelation.size(source) expects one integer argument in kernels", pos);
            }
            var paramId = paramIds.get(name);
            writer.u8(EXPR_MESH_RELATION_SIZE);
            writer.u32(paramId);
            encodeExpression(args[0], writer);
            true;
          default:
            false;
        }
      default:
        false;
    };
  }

  function encodeAssumeInRangeCall(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 4) {
      Context.error("Quadrants CompilerHints.assumeInRange expects value, base, low, and high", pos);
    }
    var low = staticIntLiteral(args[2], args[2].pos);
    var high = staticIntLiteral(args[3], args[3].pos);
    if (high <= low) {
      Context.error("Quadrants CompilerHints.assumeInRange high bound must be greater than low bound", pos);
    }
    writer.u8(EXPR_ASSUME_IN_RANGE);
    encodeExpression(args[0], writer);
    encodeExpression(args[1], writer);
    writer.i32(low);
    writer.i32(high);
  }


  function encodePackedMemberReadCall(path:String, args:Array<Expr>, writer:ByteWriter, pos:Position):Bool {
    if (!StringTools.endsWith(path, "PackedHelpers.readMemberI32") && !StringTools.endsWith(path, "PackedHelpers.readMemberF32")) {
      return false;
    }
    if (args.length != 2) {
      Context.error("Quadrants packed member read helper expects member and index", pos);
    }
    writer.u8(EXPR_LOAD_INDEX);
    encodeArrayBase(args[0], writer, 1);
    writer.u32(1);
    encodeArrayIndices(args[0], [args[1]], writer);
    return true;
  }
  function randomCallDType(name:String):Null<Int> {
    return switch (name) {
      case "randI32": DTYPE_I32;
      case "randU32": DTYPE_U32;
      case "randI64": DTYPE_I64;
      case "randU64": DTYPE_U64;
      case "randF32": DTYPE_F32;
      case "randF64": DTYPE_F64;
      default: null;
    };
  }

  function randnCallDType(name:String):Null<Int> {
    return switch (name) {
      case "randnF32": DTYPE_F32;
      case "randnF64": DTYPE_F64;
      default: null;
    };
  }

  function frexpCallDType(name:String):Null<Int> {
    return switch (name) {
      case "frexpF32": DTYPE_F32;
      case "frexpF64": DTYPE_F64;
      default: null;
    };
  }

  function frexpCallInfo(expression:Expr):Null<{dtype:Int, args:Array<Expr>, pos:Position}> {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case ECall(callee, args):
        var dtype = frexpCallDType(callName(callee, expr.pos));
        if (dtype == null) {
          null;
        } else {
          if (args.length != 1) {
            Context.error("Quadrants HashLink frexpF32/frexpF64 expect one argument", expr.pos);
          }
          {dtype: dtype, args: args, pos: expr.pos};
        }
      default:
        null;
    };
  }

  function frexpStructInitializer(expression:Expr):Null<Array<{name:String, value:Expr, dtype:Int}>> {
    var info = frexpCallInfo(expression);
    if (info == null) {
      return null;
    }
    return [
      {name: "significand", value: {expr: EField(expression, "significand"), pos: info.pos}, dtype: info.dtype},
      {name: "exponent", value: {expr: EField(expression, "exponent"), pos: info.pos}, dtype: DTYPE_I32}
    ];
  }

  function frexpFieldAccessDType(expression:Expr):Null<Int> {
    return switch (stripNoCasts(expression).expr) {
      case EField(base, field):
        var info = frexpCallInfo(base);
        if (info == null) {
          null;
        } else {
          switch (field) {
            case "significand" | "mantissa": info.dtype;
            case "exponent": DTYPE_I32;
            default: Context.error("Quadrants frexp result exposes .significand and .exponent", expression.pos);
          }
        }
      default:
        null;
    };
  }

  function encodeFrexpFieldAccess(expression:Expr, writer:ByteWriter):Bool {
    switch (stripNoCasts(expression).expr) {
      case EField(base, field):
        var info = frexpCallInfo(base);
        if (info == null) {
          return false;
        }
        switch (field) {
          case "significand" | "mantissa":
            writer.u8(EXPR_FREXP_SIGNIFICAND);
          case "exponent":
            writer.u8(EXPR_FREXP_EXPONENT);
          default:
            Context.error("Quadrants frexp result exposes .significand and .exponent", expression.pos);
        }
        encodeExpressionWithExpectedDType(info.args[0], info.dtype, writer);
        return true;
      default:
        return false;
    }
  }

  function writeFloatConstant(dtype:Int, value:Float, writer:ByteWriter):Void {
    if (dtype == DTYPE_F32) {
      writer.u8(EXPR_CONST_F32);
      writer.f32(value);
    } else {
      writer.u8(EXPR_CONST_F64);
      writer.f64(value);
    }
  }

  function encodeRandnCall(name:String, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 0) {
      Context.error('Quadrants HashLink function ${name} expects no arguments', pos);
    }
    var dtype = randnCallDType(name);
    writer.u8(EXPR_BINARY_MUL);
    writer.u8(EXPR_SQRT);
    writer.u8(EXPR_BINARY_MUL);
    writeFloatConstant(dtype, -2.0, writer);
    writer.u8(EXPR_LOG);
    writer.u8(EXPR_BINARY_SUB);
    writeFloatConstant(dtype, 1.0, writer);
    writer.u8(EXPR_RAND);
    writer.u8(dtype);
    writer.u8(EXPR_COS);
    writer.u8(EXPR_BINARY_MUL);
    writeFloatConstant(dtype, 6.283185307179586, writer);
    writer.u8(EXPR_RAND);
    writer.u8(dtype);
  }

  function encodeRawDivModCall(name:String, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 2) {
      Context.error('Quadrants HashLink function ${name} expects two arguments', pos);
    }
    writer.u8(name == "rawDiv" ? EXPR_BINARY_DIV : EXPR_BINARY_MOD);
    encodeExpression(args[0], writer);
    encodeExpression(args[1], writer);
  }

  function encodeFnsU32Call(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 3) {
      Context.error("Quadrants HashLink function fnsU32 expects mask, base, and offset", pos);
    }
    writer.u8(EXPR_FNS_U32);
    encodeExpressionWithExpectedDType(args[0], DTYPE_U32, writer);
    encodeExpressionWithExpectedDType(args[1], DTYPE_U32, writer);
    encodeExpressionWithExpectedDType(args[2], DTYPE_I32, writer);
  }

  function encodeVolatileLoadCall(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 1) {
      Context.error("Quadrants HashLink function volatileLoad expects one ndarray element argument", pos);
    }
    switch (strip(args[0]).expr) {
      case EArray(_, _):
      default:
        Context.error("Quadrants HashLink volatileLoad target must be an ndarray element", args[0].pos);
    }
    var access = collectArrayAccess(args[0]);
    switch (strip(access.base).expr) {
      case EConst(CIdent(name)):
        var localId = lookupLocal(name);
        if (localId != null && locals[localId].sharedSize > 0) {
          Context.error("Quadrants HashLink volatileLoad on shared locals is not yet supported by the HashLink descriptor backend", args[0].pos);
        }
      default:
    }
    writer.u8(EXPR_VOLATILE_LOAD_INDEX);
    encodeArrayBase(access.base, writer, access.indices.length);
    writer.u32(access.indices.length);
    encodeArrayIndices(access.base, access.indices, writer);
  }

  function builtinCallOpcode(name:String):Null<Int> {
    return switch (name) {
      case "abs": EXPR_UNARY_ABS;
      case "sin": EXPR_SIN;
      case "asin": EXPR_ASIN;
      case "cos": EXPR_COS;
      case "acos": EXPR_ACOS;
      case "tan": EXPR_TAN;
      case "exp": EXPR_EXP;
      case "log": EXPR_LOG;
      case "sqrt": EXPR_SQRT;
      case "rsqrt": EXPR_RSQRT;
      case "floor": EXPR_FLOOR;
      case "ceil": EXPR_CEIL;
      case "round": EXPR_ROUND;
      case "tanh": EXPR_TANH;
      case "inv": EXPR_INV;
      case "rcp": EXPR_RCP;
      case "popcnt": EXPR_POPCNT;
      case "clz": EXPR_CLZ;
      case "ffs": EXPR_FFS;
      case "sgn": EXPR_SGN;
      case "min": EXPR_MIN;
      case "max": EXPR_MAX;
      case "atan2": EXPR_ATAN2;
      case "pow": EXPR_POW;
      default: null;
    };
  }

  function internalExpressionOpcode(path:String):Null<Int> {
    if (pathIs(path, "Block", "threadIdx")) return EXPR_BLOCK_THREAD_IDX;
    if (pathIs(path, "Block", "barrierAnd")) return EXPR_BLOCK_BARRIER_AND;
    if (pathIs(path, "Block", "barrierOr")) return EXPR_BLOCK_BARRIER_OR;
    if (pathIs(path, "Block", "barrierCount")) return EXPR_BLOCK_BARRIER_COUNT;
    if (pathIs(path, "Subgroup", "size")) return EXPR_SUBGROUP_SIZE;
    if (pathIs(path, "Subgroup", "invocationId")) return EXPR_SUBGROUP_INVOCATION_ID;
    if (pathIs(path, "Subgroup", "elect")) return EXPR_SUBGROUP_ELECT;
    if (pathIs(path, "Subgroup", "shuffle")) return EXPR_SUBGROUP_SHUFFLE;
    if (pathIs(path, "Subgroup", "shuffleDown")) return EXPR_SUBGROUP_SHUFFLE_DOWN;
    if (pathIs(path, "Subgroup", "shuffleUp")) return EXPR_SUBGROUP_SHUFFLE_UP;
    if (pathIs(path, "Subgroup", "broadcast")) return EXPR_SUBGROUP_BROADCAST;
    if (pathIs(path, "Workgroup", "localInvocationId")) return EXPR_LOCAL_INVOCATION_ID;
    if (pathIs(path, "Workgroup", "globalInvocationId")) return EXPR_GLOBAL_INVOCATION_ID;
    if (pathIs(path, "Grid", "vkGlobalThreadIdx")) return EXPR_VK_GLOBAL_THREAD_IDX;
    if (pathIs(path, "Grid", "activeMask")) return EXPR_CUDA_ACTIVE_MASK;
    if (pathIs(path, "Subgroup", "ballot")) return EXPR_SUBGROUP_BALLOT_U64;
    if (pathIs(path, "Grid", "matchAnySync")) return EXPR_CUDA_MATCH_ANY;
    if (pathIs(path, "Grid", "matchAllSync")) return EXPR_CUDA_MATCH_ALL;
    if (pathIs(path, "SpecialOps", "clockI64") || pathIs(path, "quadrants.SpecialOps", "clockI64")) return EXPR_CLOCK_I64;
    return null;
  }

  function encodeInternalExpressionCall(path:String, opcode:Int, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    writer.u8(opcode);
    if (opcode == EXPR_SUBGROUP_SHUFFLE || opcode == EXPR_SUBGROUP_SHUFFLE_DOWN || opcode == EXPR_SUBGROUP_SHUFFLE_UP || opcode == EXPR_SUBGROUP_BROADCAST || opcode == EXPR_CUDA_MATCH_ANY || opcode == EXPR_CUDA_MATCH_ALL) {
      if (args.length != 2) {
        Context.error('Quadrants HashLink function ${path} expects two arguments', pos);
      }
      encodeExpression(args[0], writer);
      encodeExpression(args[1], writer);
      return;
    }
    if (opcode == EXPR_BLOCK_BARRIER_AND || opcode == EXPR_BLOCK_BARRIER_OR || opcode == EXPR_BLOCK_BARRIER_COUNT || opcode == EXPR_SUBGROUP_BALLOT_U64) {
      if (args.length != 1) {
        Context.error('Quadrants HashLink function ${path} expects one argument', pos);
      }
      encodeExpression(args[0], writer);
      return;
    }
    if (args.length != 0) {
      Context.error('Quadrants HashLink function ${path} expects no arguments', pos);
    }
  }

  function encodeSelectCall(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 3) {
      Context.error("Quadrants HashLink function select expects 3 arguments", pos);
    }
    writer.u8(EXPR_SELECT);
    encodeExpression(args[0], writer);
    encodeExpression(args[1], writer);
    encodeExpression(args[2], writer);
  }


  function encodeFloatingPredicateCall(name:String, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 1) {
      Context.error('Quadrants HashLink function ${name} expects 1 argument', pos);
    }
    if (name == "isnan") {
      encodeExpression(binaryExpr(OpNotEq, args[0], args[0], pos), writer);
      return;
    }
    var absExpr:Expr = {expr: ECall({expr: EConst(CIdent("abs")), pos: pos}, [args[0]]), pos: pos};
    var one:Expr = {expr: EConst(CFloat("1.0", null)), pos: pos};
    var zero:Expr = {expr: EConst(CFloat("0.0", null)), pos: pos};
    var inf:Expr = binaryExpr(OpDiv, one, zero, pos);
    encodeExpression(binaryExpr(OpEq, absExpr, inf, pos), writer);
  }
  function encodeShapeCall(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 2) {
      Context.error("Quadrants HashLink function shape expects 2 arguments", pos);
    }
    var axis = constantIndex(args[1], args[1].pos);
    if (axis < 0) {
      Context.error("Quadrants HashLink shape axis must be non-negative", args[1].pos);
    }
    switch (strip(args[0]).expr) {
      case EConst(CIdent(name)):
        var paramId = paramIds.get(name);
        if (paramId == null) {
          Context.error('Quadrants shape target ${name} is not a kernel parameter', args[0].pos);
        }
        var viewLengthParamId = bufferViewLengthParamIds.get(name);
        if (viewLengthParamId != null) {
          if (axis != 0) {
            Context.error("Quadrants BufferView shape axis must be zero", args[1].pos);
          }
          writer.u8(EXPR_ARG_LOAD);
          writer.u32(viewLengthParamId);
          return;
        }
        var param = params[paramId];
        if (param.kind == PARAM_SCALAR) {
          Context.error('Quadrants shape target ${name} is used as a scalar', args[0].pos);
        }
        param.kind = PARAM_NDARRAY;
        var requiredRank = axis + 1;
        if (param.rank < requiredRank) {
          param.rank = requiredRank;
          param.rankFromShape = true;
        }
        writer.u8(EXPR_SHAPE_AXIS);
        writer.u8(EXPR_ARG_LOAD);
        writer.u32(paramId);
        writer.u32(axis);
      default:
        Context.error("Quadrants HashLink shape target must be a direct Tensor or Field parameter", args[0].pos);
    }
  }

  function encodeAtanCall(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 1) {
      Context.error("Quadrants HashLink function atan expects 1 argument", pos);
    }
    var dtype = inferExpressionDType(args[0]);
    writer.u8(EXPR_ATAN2);
    encodeExpression(args[0], writer);
    if (dtype == DTYPE_F64) {
      writer.u8(EXPR_CONST_F64);
      writer.f64(1.0);
    } else {
      encodeTypedConstant({expr: EConst(CFloat("1.0", null)), pos: pos}, dtype == DTYPE_F16 ? DTYPE_F16 : DTYPE_F32, writer, pos);
    }
  }

  function tensorMethodTarget(callee:Expr, method:String):Null<Expr> {
    return switch (strip(callee).expr) {
      case EField(base, field) if (field == method):
        base;
      default:
        null;
    };
  }

  function tensorReadDType(callee:Expr):Null<Int> {
    var target = tensorMethodTarget(callee, "scalarRead");
    if (target == null) {
      target = tensorMethodTarget(callee, "read");
    }
    if (target == null) {
      target = tensorMethodTarget(callee, "kernelRead");
    }
    if (target == null) {
      return null;
    }
    return switch (strip(target).expr) {
      case EConst(CIdent(name)):
        var inlineArg = lookupInlineArg(name);
        if (inlineArg != null) {
          inferExpressionDType(inlineArg);
        } else {
          var localId = lookupLocal(name);
          if (localId != null) {
            locals[localId].dtype;
          } else {
            var paramId = paramIds.get(name);
            paramId == null ? DTYPE_I32 : params[paramId].dtype;
          }
        }
      default:
        DTYPE_I32;
    };
  }

  function shapeMethodTarget(callee:Expr):Null<Expr> {
    return switch (strip(callee).expr) {
      case EField(base, "shape") | EField(base, "dim"):
        base;
      default:
        null;
    };
  }

  function encodeBitCastCall(args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    if (args.length != 2) {
      Context.error("Quadrants HashLink function bitCast expects 2 arguments", pos);
    }
    writer.u8(EXPR_BIT_CAST);
    writer.u8(dtypeFromTypeExpression(args[1], args[1].pos));
    encodeExpression(args[0], writer);
  }

  function inlineFunctionCall(expression:Expr):Null<{info:QdFunctionInfo, args:Array<Expr>}> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case ECall(callee, args):
        var info = functions.get(callName(callee, expr.pos));
        info == null ? null : {info: info, args: args};
      default:
        null;
    };
  }

  function qdFunctionMetadataArgTypeInfo(type:Null<ComplexType>, pos:Position):{kind:Int, dtype:Int, needsGrad:Bool, spec:Bool} {
    if (isKernelLocalAggregateType(type)) {
      return {kind: PARAM_SCALAR, dtype: DTYPE_I32, needsGrad: false, spec: false};
    }
    return parameterTypeInfo(type, pos);
  }

  function isKernelLocalAggregateType(type:Null<ComplexType>):Bool {
    return switch (type) {
      case TPath(path):
        (path.name == "Vector" || path.name == "Matrix") && (path.pack.length == 0 || path.pack.join(".") == "quadrants");
      default:
        false;
    };
  }

  function qdFunctionMetadataReturnDType(info:QdFunctionInfo):Int {
    return switch (info.ret) {
      case null:
        DTYPE_I32;
      case TPath(path) if ((path.name == "Vector" || path.name == "Matrix") && (path.pack.length == 0 || path.pack.join(".") == "quadrants")):
        DTYPE_I32;
      default:
        dtypeFromComplexType(info.ret, info.pos);
    };
  }

  function qdFunctionReturns(info:QdFunctionInfo, typeName:String):Bool {
    return switch (info.ret) {
      case TPath(path):
        path.name == typeName && (path.pack.length == 0 || path.pack.join(".") == "quadrants");
      default:
        false;
    };
  }

  function localLoadExpr(localId:Int):Expr {
    return {expr: EConst(CIdent(locals[localId].name)), pos: Context.currentPos()};
  }

  function emitInlineFunctionToTemp(info:QdFunctionInfo, args:Array<Expr>, writer:ByteWriter, pos:Position):{localId:Int, count:Int} {
    var dtype = info.ret == null ? DTYPE_I32 : dtypeFromComplexType(info.ret, pos);
    var localId = declareLocal(uniqueLocalName("__qd_func_ret"), pos, true, dtype);
    beginInlineFunctionScope(info, args, pos);
    pushScope();
    inlineReturnTargets.push(localId);
    var count = encodeStatementList(statementsOf(info.body), writer);
    inlineReturnTargets.pop();
    popScope();
    finishInlineFunctionCall();
    return {localId: localId, count: count};
  }

  function encodeInlineFunctionStatementCall(info:QdFunctionInfo, args:Array<Expr>, writer:ByteWriter, pos:Position):Int {
    beginInlineFunctionScope(info, args, pos);
    pushScope();
    var count = encodeStatementList(statementsOf(info.body), writer);
    popScope();
    finishInlineFunctionCall();
    return count;
  }

  function beginInlineFunctionScope(info:QdFunctionInfo, args:Array<Expr>, pos:Position):Void {
    if (inlineFunctionStack.indexOf(info.name) >= 0) {
      Context.error('Quadrants qdFunc ${info.name} is recursive; recursive kernel functions are not supported', pos);
    }
    if (args.length != info.args.length) {
      Context.error('Quadrants qdFunc ${info.name} expects ${info.args.length} argument(s)', pos);
    }
    var argScope = new Map<String, Expr>();
    for (i in 0...args.length) {
      var actual = substituteInlineArgs(args[i]);
      argScope[info.args[i].name] = preserveInlineF32ArgumentType(info.args[i].type, actual);
    }
    inlineFunctionStack.push(info.name);
    inlineArgScopes.push(argScope);
  }

  function preserveInlineF32ArgumentType(type:Null<ComplexType>, actual:Expr):Expr {
    var isF32 = switch (type) {
      case TPath(path):
        switch (typePathName(path)) {
          case "hl.F32", "F32", "quadrants.F32", "quadrants.Types.F32", "Types.F32": true;
          default: false;
        }
      default:
        false;
    };
    return isF32 ? {expr: ECheckType(actual, type), pos: actual.pos} : actual;
  }

  function encodeInlineFunctionCall(info:QdFunctionInfo, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    var result = beginInlineFunctionCall(info, args, pos);
    encodeExpression(result, writer);
    finishInlineFunctionCall();
  }

  function beginInlineFunctionCall(info:QdFunctionInfo, args:Array<Expr>, pos:Position):Expr {
    beginInlineFunctionScope(info, args, pos);
    return inlineFunctionReturnExpression(info);
  }

  function finishInlineFunctionCall():Void {
    inlineArgScopes.pop();
    inlineFunctionStack.pop();
  }


  function substituteInlineArgs(expression:Expr):Expr {
    var expr = stripNoCasts(expression);
    switch (expr.expr) {
      case EConst(CIdent(name)):
        var inlineArg = lookupInlineArg(name);
        if (inlineArg == null || directIdentifier(inlineArg) == name) {
          return expr;
        }
        return substituteInlineArgs(inlineArg);
      case EArray(base, index):
        return {expr: EArray(substituteInlineArgs(base), substituteInlineArgs(index)), pos: expr.pos};
      case EBinop(op, lhs, rhs):
        return {expr: EBinop(op, substituteInlineArgs(lhs), substituteInlineArgs(rhs)), pos: expr.pos};
      case EUnop(op, postfix, operand):
        return {expr: EUnop(op, postfix, substituteInlineArgs(operand)), pos: expr.pos};
      case ECall(callee, args):
        return {expr: ECall(substituteInlineArgs(callee), [for (arg in args) substituteInlineArgs(arg)]), pos: expr.pos};
      case EField(base, field):
        return {expr: EField(substituteInlineArgs(base), field), pos: expr.pos};
      case ECast(inner, type):
        return {expr: ECast(substituteInlineArgs(inner), type), pos: expr.pos};
      case ECheckType(inner, type):
        return {expr: ECheckType(substituteInlineArgs(inner), type), pos: expr.pos};
      case EIf(condition, ifExpr, elseExpr):
        return {expr: EIf(substituteInlineArgs(condition), substituteInlineArgs(ifExpr),
            elseExpr == null ? null : substituteInlineArgs(elseExpr)), pos: expr.pos};
      case ETernary(condition, ifExpr, elseExpr):
        return {expr: ETernary(substituteInlineArgs(condition), substituteInlineArgs(ifExpr), substituteInlineArgs(elseExpr)), pos: expr.pos};
      case EParenthesis(inner):
        return {expr: EParenthesis(substituteInlineArgs(inner)), pos: expr.pos};
      default:
        return expr;
    }
  }

  function inlineFunctionReturnExpressionOrNull(info:QdFunctionInfo):Null<Expr> {
    var body = strip(info.body);
    return switch (body.expr) {
      case EReturn(returned) if (returned != null):
        returned;
      case EBlock(expressions) if (expressions.length == 1):
        inlineFunctionReturnExpressionOrNull({name: info.name, owner: info.owner, args: info.args, body: expressions[0], ret: info.ret, pos: info.pos});
      case EBlock(_):
        null;
      default:
        body;
    };
  }
  function inlineFunctionReturnExpression(info:QdFunctionInfo):Expr {
    var body = strip(info.body);
    return switch (body.expr) {
      case EReturn(returned) if (returned != null):
        returned;
      case EBlock(expressions) if (expressions.length == 1):
        inlineFunctionReturnExpression({name: info.name, owner: info.owner, args: info.args, body: expressions[0], ret: info.ret, pos: info.pos});
      case EBlock(expressions) if (expressions.length > 0):
        var last = strip(expressions[expressions.length - 1]);
        switch (last.expr) {
          case EReturn(returned) if (returned != null && expressions.length == 1):
            returned;
          default:
            Context.error('Quadrants qdFunc ${info.name} must be a single return expression in the HashLink frontend', info.pos);
        }
      default:
        body;
    };
  }

  function atomicExpressionOpcode(name:String):Null<Int> {
    return switch (name) {
      case "atomicAdd": EXPR_ATOMIC_ADD;
      case "atomicSub": EXPR_ATOMIC_SUB;
      case "atomicMin": EXPR_ATOMIC_MIN;
      case "atomicMax": EXPR_ATOMIC_MAX;
      case "atomicAnd": EXPR_ATOMIC_AND;
      case "atomicOr": EXPR_ATOMIC_OR;
      case "atomicXor": EXPR_ATOMIC_XOR;
      case "atomicExchange": EXPR_ATOMIC_EXCHANGE;
      case "atomicMul": EXPR_ATOMIC_MUL;
      case "atomicCompareExchange": EXPR_ATOMIC_COMPARE_EXCHANGE;
      default: null;
    }
  }

  function encodeAtomicCall(name:String, opcode:Int, args:Array<Expr>, writer:ByteWriter, pos:Position):Void {
    var expectedArity = opcode == EXPR_ATOMIC_COMPARE_EXCHANGE ? 3 : 2;
    if (args.length != expectedArity) {
      Context.error('Quadrants HashLink function ${name} expects ${expectedArity} argument(s)', pos);
    }
    switch (strip(args[0]).expr) {
      case EArray(_, _):
      default:
        Context.error('Quadrants HashLink ${name} target must be an ndarray element', args[0].pos);
    }
    var access = collectArrayAccess(args[0]);
    writer.u8(opcode);
    encodeArrayBase(access.base, writer, access.indices.length);
    writer.u32(access.indices.length);
    encodeArrayIndices(access.base, access.indices, writer);
    if (opcode == EXPR_ATOMIC_COMPARE_EXCHANGE) {
      encodeExpression(args[1], writer);
      encodeExpression(args[2], writer);
    } else {
      encodeExpression(args[1], writer);
    }
  }

  function callName(callee:Expr, pos:Position):String {
    var expr = strip(callee);
    return switch (expr.expr) {
      case EConst(CIdent(name)): name;
      case EField(_, field): field;
      default: Context.error("Unsupported Quadrants HashLink function callee", pos);
    };
  }

  function callPath(callee:Expr, pos:Position):String {
    var expr = strip(callee);
    return switch (expr.expr) {
      case EConst(CIdent(name)): name;
      case EField(base, field): callPath(base, pos) + "." + field;
      default: Context.error("Unsupported Quadrants HashLink function callee", pos);
    };
  }

  function pathIs(path:String, typeName:String, methodName:String):Bool {
    var suffix = typeName + "." + methodName;
    return path == suffix || path == "quadrants." + suffix;
  }

  function internalStatementOpcode(path:String):Null<Int> {
    if (pathIs(path, "Block", "sync") || pathIs(path, "Block", "barrier")) return STMT_BLOCK_BARRIER;
    if (pathIs(path, "Block", "memFence")) return STMT_BLOCK_MEM_FENCE;
    if (pathIs(path, "Block", "warpSync")) return STMT_WARP_BARRIER;
    if (pathIs(path, "Grid", "memFence")) return STMT_GRID_MEM_FENCE;
    if (pathIs(path, "Workgroup", "sync") || pathIs(path, "Workgroup", "barrier")) return STMT_WORKGROUP_BARRIER;
    if (pathIs(path, "Workgroup", "memFence")) return STMT_WORKGROUP_MEMORY_BARRIER;
    if (pathIs(path, "Workgroup", "gridMemFence")) return STMT_GRID_MEMORY_BARRIER;
    if (pathIs(path, "Subgroup", "sync") || pathIs(path, "Subgroup", "barrier")) return STMT_SUBGROUP_BARRIER;
    if (pathIs(path, "Subgroup", "memFence")) return STMT_SUBGROUP_MEMORY_BARRIER;
    return null;
  }

  function isGroupedCall(callee:Expr):Bool {
    var path = callPath(callee, callee.pos);
    return path == "Grouped.of" || path == "quadrants.Grouped.of";
  }
  function groupedStructForTarget(args:Array<Expr>):Null<Expr> {
    if (args.length < 1 || args.length > 2) {
      return null;
    }
    var target = strip(args[0]);
    return switch (target.expr) {
      case EConst(CIdent(name)):
        var paramId = paramIds.get(name);
        if (paramId != null && (params[paramId].kind == PARAM_NDARRAY || params[paramId].kind == PARAM_FIELD)) target else null;
      default:
        null;
    };
  }


  function isStaticRangeCall(callee:Expr):Bool {
    var path = callPath(callee, callee.pos);
    return path == "Static.range" || path == "quadrants.Static.range";
  }

  function isStaticValuesCall(callee:Expr):Bool {
    var path = callPath(callee, callee.pos);
    return path == "Static.values" || path == "quadrants.Static.values";
  }

  function isStaticValueCall(callee:Expr):Bool {
    var path = callPath(callee, callee.pos);
    return path == "Static.value" || path == "quadrants.Static.value";
  }

  function encodeSNodeStatementCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Null<Int> {
    var activateTarget = tensorMethodTarget(callee, "activate");
    if (activateTarget != null) {
      if (args.length != 1) {
        Context.error("Quadrants Field.activate(index) expects one argument", pos);
      }
      writer.u8(STMT_SNODE_ACTIVATE);
      encodeFieldBase(activateTarget, writer, args.length, pos);
      writer.u32(1);
      encodeArrayIndices(activateTarget, [args[0]], writer);
      return 1;
    }
    var deactivateTarget = tensorMethodTarget(callee, "deactivate");
    if (deactivateTarget != null) {
      if (args.length != 1) {
        Context.error("Quadrants Field.deactivate(index) expects one argument", pos);
      }
      writer.u8(STMT_SNODE_DEACTIVATE);
      encodeFieldBase(deactivateTarget, writer, args.length, pos);
      writer.u32(1);
      encodeArrayIndices(deactivateTarget, [args[0]], writer);
      return 1;
    }
    return null;
  }

  function encodeSNodeExpressionCall(callee:Expr, args:Array<Expr>, writer:ByteWriter, pos:Position):Bool {
    var appendTarget = tensorMethodTarget(callee, "append");
    if (appendTarget != null) {
      if (args.length != 2) {
        Context.error("Quadrants Field.append(index, value) expects two arguments", pos);
      }
      writer.u8(EXPR_SNODE_APPEND);
      encodeFieldBase(appendTarget, writer, args.length, pos);
      writer.u32(1);
      encodeArrayIndices(appendTarget, [args[0]], writer);
      encodeExpression(args[1], writer);
      return true;
    }
    var lengthTarget = tensorMethodTarget(callee, "length");
    if (lengthTarget != null) {
      if (args.length != 1) {
        Context.error("Quadrants Field.length(index) expects one argument", pos);
      }
      writer.u8(EXPR_SNODE_LENGTH);
      encodeFieldBase(lengthTarget, writer, args.length + 1, pos);
      writer.u32(1);
      encodeArrayIndices(lengthTarget, [args[0]], writer);
      return true;
    }
    var activeTarget = tensorMethodTarget(callee, "isActive");
    if (activeTarget != null) {
      if (args.length != 1) {
        Context.error("Quadrants Field.isActive(index) expects one argument", pos);
      }
      writer.u8(EXPR_SNODE_IS_ACTIVE);
      encodeFieldBase(activeTarget, writer, args.length, pos);
      writer.u32(1);
      encodeArrayIndices(activeTarget, [args[0]], writer);
      return true;
    }
    return false;
  }

  function encodeFieldBase(base:Expr, writer:ByteWriter, rank:Int, pos:Position):Void {
    var expr = strip(base);
    switch (expr.expr) {
      case EConst(CIdent(name)):
        var paramId = paramIds.get(name);
        if (paramId == null) {
          Context.error('Quadrants field ${name} is not a kernel parameter', expr.pos);
        }
        markParamField(paramId, rank, pos);
        writer.u8(EXPR_ARG_LOAD);
        writer.u32(paramId);
      default:
        Context.error("Quadrants SNode operations require a direct Field kernel parameter", expr.pos);
    }
  }

  function markParamScalar(paramId:Int, pos:Position):Void {
    var param = params[paramId];
    if (param.kind == PARAM_NDARRAY) {
      Context.error('Quadrants parameter ${param.name} is used as both ndarray and scalar', pos);
    }
    if (param.kind == PARAM_FIELD || param.kind == PARAM_MESH_ATTRIBUTE || param.kind == PARAM_MESH_RELATION) {
      Context.error('Quadrants parameter ${param.name} is used as both resource and scalar', pos);
    }
    param.kind = PARAM_SCALAR;
    param.rank = 0;
    param.needsGrad = false;
  }

  function markParamNdarray(paramId:Int, rank:Int, pos:Position):Void {
    var param = params[paramId];
    if (param.kind == PARAM_FIELD || param.kind == PARAM_MESH_ATTRIBUTE || param.kind == PARAM_MESH_RELATION) {
      Context.error('Quadrants Field or mesh resource parameter ${param.name} cannot be used as a Tensor ndarray', pos);
    }
    if (param.kind == PARAM_SCALAR) {
      Context.error('Quadrants parameter ${param.name} is used as both scalar and ndarray', pos);
    }
    if (param.kind == PARAM_NDARRAY && param.rank != 0 && param.rank != rank) {
      if (!param.rankFromShape) {
        Context.error('Quadrants ndarray parameter ${param.name} is used with inconsistent rank', pos);
      }
      if (rank < param.rank) {
        Context.error('Quadrants ndarray parameter ${param.name} is used with inconsistent rank', pos);
      }
    }
    param.kind = PARAM_NDARRAY;
    param.rank = rank;
    param.needsGrad = needsGradForDType(param.dtype);
    param.rankFromShape = false;
  }

  function markParamField(paramId:Int, rank:Int, pos:Position):Void {
    var param = params[paramId];
    if (param.kind == PARAM_NDARRAY) {
      Context.error('Quadrants Tensor parameter ${param.name} cannot be used as a Field SNode', pos);
    }
    if (param.kind == PARAM_MESH_RELATION) {
      Context.error('Quadrants MeshRelation parameter ${param.name} cannot be used as a Field SNode', pos);
    }
    if (param.kind == PARAM_SCALAR) {
      Context.error('Quadrants parameter ${param.name} is used as both scalar and field', pos);
    }
    if ((param.kind == PARAM_FIELD || param.kind == PARAM_MESH_ATTRIBUTE) && param.rank != 0 && param.rank != rank) {
      if (!param.rankFromShape) {
        Context.error('Quadrants field parameter ${param.name} is used with inconsistent rank', pos);
      }
      if (rank < param.rank) {
        Context.error('Quadrants field parameter ${param.name} is used with inconsistent rank', pos);
      }
    }
    if (param.kind != PARAM_MESH_ATTRIBUTE) {
      param.kind = PARAM_FIELD;
    }
    param.rank = rank;
    param.needsGrad = needsGradForDType(param.dtype);
    param.rankFromShape = false;
  }

  function returnTupleElements(expression:Expr):Null<Array<Expr>> {
    var expr = stripNoCasts(expression);
    var vectorName = directVectorName(expr);
    if (vectorName != null) {
      var vector = lookupVector(vectorName);
      return [for (i in 0...vector.localIds.length) vectorComponentExpr(vectorName, i, expr.pos)];
    }
    var matrixName = directMatrixName(expr);
    if (matrixName != null) {
      var matrix = lookupMatrix(matrixName);
      return [for (row in 0...matrix.rows) for (col in 0...matrix.cols) matrixElementExpr(matrixName, row, col, expr.pos)];
    }
    var inlineStruct = structInitializer(expr);
    if (inlineStruct != null) {
      return [for (field in inlineStruct) field.value];
    }

    switch (expr.expr) {
      case EConst(CIdent(name)):
        var struct = lookupStruct(name);
        if (struct != null) {
          return [for (fieldName in struct.order) localLoadExpr(struct.fields.get(fieldName).localId)];
        }
      default:
    }
    return switch (expr.expr) {
      case EArrayDecl(values):
        if (values.length == 0) {
          Context.error("Quadrants tuple return must contain at least one value", expr.pos);
        }
        values;
      default:
        null;
    };
  }

  function noteReturn(dtype:Int, pos:Position):Void {
    noteReturnDTypes([dtype], pos);
  }

  function noteReturnDTypes(dtypes:Array<Int>, pos:Position):Void {
    if (dtypes.length == 0) {
      Context.error("Quadrants HashLink kernel return must contain at least one value", pos);
    }
    if (hasReturn) {
      if (returnDTypes.length != dtypes.length) {
        Context.error("Quadrants HashLink kernel return arity must be consistent", pos);
      }
      for (i in 0...dtypes.length) {
        if (returnDTypes[i] != dtypes[i]) {
          Context.error("Quadrants HashLink kernel return dtype must be consistent", pos);
        }
      }
    }
    hasReturn = true;
    returnDType = dtypes[0];
    returnDTypes = dtypes.copy();
  }

  function inferExpressionDType(expression:Expr):Int {
    var expr = stripNoCasts(expression);
    return switch (expr.expr) {
      case EConst(CIdent("true")) | EConst(CIdent("false")):
        DTYPE_U1;
      case EConst(CFloat(_, _)):
        DTYPE_F64;
      case EConst(CInt(_, _)):
        DTYPE_I32;
      case EConst(CIdent(name)):
        var inlineArg = lookupInlineArg(name);
        if (inlineArg != null) {
          inferExpressionDType(inlineArg);
        } else {
          var localId = lookupLocal(name);
          if (localId != null) {
            locals[localId].dtype;
          } else {
            var paramId = paramIds.get(name);
            paramId == null ? DTYPE_I32 : params[paramId].dtype;
          }
        }
      case EArray(base, _):
        var matrixLocalId = matrixElementLocalId(expr);
        if (matrixLocalId != null) {
          locals[matrixLocalId].dtype;
        } else {
          var vectorName = directVectorName(base);
          if (vectorName != null) {
            lookupVector(vectorName).dtype;
          } else {
            var access = collectArrayAccess(expr);
            switch (strip(access.base).expr) {
              case EConst(CIdent(name)):
                var indexVector = lookupIndexVector(name);
                if (indexVector != null) {
                  DTYPE_I32;
                } else {
                  var inlineArg = lookupInlineArg(name);
                  if (inlineArg != null) {
                    inferExpressionDType({expr: EArray(inlineArg, access.indices[0]), pos: expr.pos});
                  } else {
                    var paramId = paramIds.get(name);
                    paramId == null ? DTYPE_I32 : params[paramId].dtype;
                  }
                }
              default:
                Context.error('Quadrants ndarray base must be a simple identifier', expr.pos);
            }
          }
        }
      case ECast(_, type) | ECheckType(_, type):
        dtypeFromComplexType(type, expr.pos);
      case EBinop(op, lhs, rhs):
        switch (op) {
          case OpEq | OpNotEq | OpLt | OpLte | OpGt | OpGte | OpBoolAnd | OpBoolOr:
            DTYPE_U1;
          default:
            promoteDType(inferExpressionDType(lhs), inferExpressionDType(rhs));
        }
      case EUnop(OpNot, _, _):
        DTYPE_U1;
      case EUnop(_, _, operand):
        inferExpressionDType(operand);
      case EIf(_, ifExpr, elseExpr) if (elseExpr != null):
        promoteDType(inferExpressionDType(ifExpr), inferExpressionDType(elseExpr));
      case ETernary(_, ifExpr, elseExpr):
        promoteDType(inferExpressionDType(ifExpr), inferExpressionDType(elseExpr));
      case ECall(callee, args):
        var meshRelationDType = meshRelationCallDType(callee, args, expr.pos);
        if (quantMethodTarget(callee, "read") != null) {
          DTYPE_F32;
        } else if (meshRelationDType != null) {
          meshRelationDType;
        } else {
        var meshAttrRead = meshAttributeMethodTarget(callee, "read");
        if (meshAttrRead != null) {
          var attrName = directIdentifier(meshAttrRead);
          params[paramIds.get(attrName)].dtype;
        } else {
        var readDType = tensorReadDType(callee);
        if (readDType != null) {
          readDType;
        } else {
          var matrixDType = matrixScalarCallDType(callee, args);
          var vectorDType = vectorScalarCallDType(callee, args);
          if (shapeMethodTarget(callee) != null) {
            DTYPE_I32;
          } else if (matrixDType != null) {
            matrixDType;
          } else if (vectorDType != null) {
            vectorDType;
          } else {
            var name = callName(callee, expr.pos);
            var path = callPath(callee, expr.pos);
            if (atomicExpressionOpcode(name) != null && args.length > 0) {
              inferExpressionDType(args[0]);
            } else if (path == "Static.value" || path == "quadrants.Static.value") {
              inferExpressionDType(args[0]);
            } else if ((path == "CompilerHints.assumeInRange" || path == "quadrants.CompilerHints.assumeInRange") && args.length > 0) {
              inferExpressionDType(args[0]);
            } else if ((name == "rawDiv" || name == "rawMod") && args.length == 2) {
              promoteDType(inferExpressionDType(args[0]), inferExpressionDType(args[1]));
            } else if (name == "fnsU32") {
              DTYPE_U32;
            } else if (name == "volatileLoad" && args.length == 1) {
              inferExpressionDType(args[0]);
            } else if ((name == "min" || name == "max" || name == "atan2" || name == "pow") && args.length == 2) {
              promoteDType(inferExpressionDType(args[0]), inferExpressionDType(args[1]));
            } else if (name == "select" && args.length == 3) {
              promoteDType(inferExpressionDType(args[1]), inferExpressionDType(args[2]));
            } else if (name == "isnan" || name == "isinf") {
              DTYPE_U1;
            } else if (randnCallDType(name) != null) {
              randnCallDType(name);
            } else if (randomCallDType(name) != null) {
              randomCallDType(name);
            } else if (name == "threadIdx" || name == "shape") {
              DTYPE_I32;
            } else if (name == "bitCast" && args.length == 2) {
              dtypeFromTypeExpression(args[1], args[1].pos);
            } else {
              var inlineFunction = functions.get(name);
              if (inlineFunction != null) {
                beginInlineFunctionScope(inlineFunction, args, expr.pos);
                var returned = inlineFunctionReturnExpressionOrNull(inlineFunction);
                var dtype = if (returned == null) {
                  inlineFunction.ret == null ? DTYPE_I32 : dtypeFromComplexType(inlineFunction.ret, expr.pos);
                } else {
                  inferExpressionDType(returned);
                }
                finishInlineFunctionCall();
                dtype;
              } else if (args.length > 0) {
                inferExpressionDType(args[0]);
              } else {
                DTYPE_I32;
              }
            }
          }
        }
        }
        }
      case EField(base, field):
        var memberAccess = structMemberAccess(expr);
        if (memberAccess != null) {
          memberAccess.member.dtype;
        } else {
          var frexpDType = frexpFieldAccessDType(expr);
          if (frexpDType != null) {
            frexpDType;
          } else {
          var vectorName = directVectorName(base);
          if (vectorName != null) {
            var vector = lookupVector(vectorName);
            var dim = vectorFieldIndex(field);
            if (dim < 0 || dim >= vector.localIds.length) {
              Context.error('Quadrants vector ${vectorName} has no component ${field}', expr.pos);
            }
            vector.dtype;
          } else {
            var structDType = structFieldDType(expr);
            structDType == null ? DTYPE_I32 : structDType;
          }
        }
      }
      default:
        DTYPE_I32;
    };
  }

  function promoteDType(lhs:Int, rhs:Int):Int {
    if (lhs == DTYPE_F64 || rhs == DTYPE_F64) return DTYPE_F64;
    if (lhs == DTYPE_F32 || rhs == DTYPE_F32) return DTYPE_F32;
    if (lhs == DTYPE_F16 || rhs == DTYPE_F16) return DTYPE_F16;
    if (lhs == DTYPE_U64 || rhs == DTYPE_U64) return DTYPE_U64;
    if (lhs == DTYPE_I64 || rhs == DTYPE_I64) return DTYPE_I64;
    if (lhs == DTYPE_U32 || rhs == DTYPE_U32) return DTYPE_U32;
    return lhs;
  }

  function pushScope():Void {
    scopes.push(new Map());
    vectorScopes.push(new Map());
    matrixScopes.push(new Map());
    structScopes.push(new Map());
  }

  function popScope():Void {
    scopes.pop();
    vectorScopes.pop();
    matrixScopes.pop();
    structScopes.pop();
  }

  function currentScope():Map<String, Int> {
    return scopes[scopes.length - 1];
  }

  function lookupLocal(name:String):Null<Int> {
    var scopeIndex = scopes.length;
    while (scopeIndex > 0) {
      scopeIndex--;
      var localId = scopes[scopeIndex].get(name);
      if (localId != null) {
        return localId;
      }
    }
    return null;
  }

  function currentInlineReturnTarget():Null<Int> {
    return inlineReturnTargets.length == 0 ? null : inlineReturnTargets[inlineReturnTargets.length - 1];
  }

  function lookupInlineArg(name:String):Null<Expr> {
    var scopeIndex = inlineArgScopes.length;
    while (scopeIndex > 0) {
      scopeIndex--;
      var arg = inlineArgScopes[scopeIndex].get(name);
      if (arg != null) {
        return arg;
      }
    }
    return null;
  }

  function lookupIndexVector(name:String):Null<Array<Int>> {
    var scopeIndex = indexVectorScopes.length;
    while (scopeIndex > 0) {
      scopeIndex--;
      var localIds = indexVectorScopes[scopeIndex].get(name);
      if (localIds != null) {
        return localIds;
      }
    }
    return null;
  }

  function currentVectorScope():Map<String, VectorLocalInfo> {
    return vectorScopes[vectorScopes.length - 1];
  }

  function lookupVector(name:String):Null<VectorLocalInfo> {
    var scopeIndex = vectorScopes.length;
    while (scopeIndex > 0) {
      scopeIndex--;
      var vector = vectorScopes[scopeIndex].get(name);
      if (vector != null) {
        return vector;
      }
    }
    return null;
  }

  function currentMatrixScope():Map<String, MatrixLocalInfo> {
    return matrixScopes[matrixScopes.length - 1];
  }

  function lookupMatrix(name:String):Null<MatrixLocalInfo> {
    var scopeIndex = matrixScopes.length;
    while (scopeIndex > 0) {
      scopeIndex--;
      var matrix = matrixScopes[scopeIndex].get(name);
      if (matrix != null) {
        return matrix;
      }
    }
    return null;
  }

  function currentStructScope():Map<String, StructLocalInfo> {
    return structScopes[structScopes.length - 1];
  }

  function lookupStruct(name:String):Null<StructLocalInfo> {
    var scopeIndex = structScopes.length;
    while (scopeIndex > 0) {
      scopeIndex--;
      var local = structScopes[scopeIndex].get(name);
      if (local != null) {
        return local;
      }
    }
    return null;
  }

  function uniqueLocalName(prefix:String):String {
    var index = locals.length;
    while (true) {
      var candidate = '${prefix}_${index}';
      if (!paramIds.exists(candidate) && lookupLocal(candidate) == null) {
        return candidate;
      }
      index++;
    }
  }

  function uniqueParameterName(prefix:String):String {
    var index = params.length;
    while (true) {
      var candidate = '${prefix}_${index}';
      if (!paramIds.exists(candidate)) {
        return candidate;
      }
      index++;
    }
  }

  function declareLocal(name:String, pos:Position, allocate:Bool, dtype:Int):Int {
    if (paramIds.exists(name)) {
      Context.error('Quadrants local variable ${name} shadows a kernel parameter', pos);
    }
    var scope = currentScope();
    if (scope.exists(name) || currentVectorScope().exists(name) || currentMatrixScope().exists(name) || currentStructScope().exists(name)) {
      Context.error('Duplicate Quadrants local variable ${name}', pos);
    }
    var id = locals.length;
    scope[name] = id;
    locals.push({name: name, allocate: allocate, dtype: dtype, sharedSize: 0});
    return id;
  }

  function declareSharedLocal(name:String, pos:Position, dtype:Int, sharedSize:Int):Int {
    if (sharedSize <= 0) {
      Context.error("Quadrants shared array size must be positive", pos);
    }
    var id = declareLocal(name, pos, false, dtype);
    locals[id].sharedSize = sharedSize;
    return id;
  }

  function ensureLocalForAssignment(name:String, pos:Position):Int {
    var existing = lookupLocal(name);
    if (existing != null) {
      return existing;
    }
    return declareLocal(name, pos, true, DTYPE_I32);
  }

  function rootStatementsOf(expression:Expr):Array<Expr> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EReturn(returned) if (returned != null):
        statementsOf(returned);
      default:
        statementsOf(expr);
    };
  }

  function statementsOf(expression:Expr):Array<Expr> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EBlock(expressions): expressions;
      default: [expr];
    }
  }

  function sourceLine(file:String, offset:Int):Int {
    if (offset < 0) {
      return 0;
    }
    var content:String;
    try {
      content = File.getContent(file);
    } catch (_:Dynamic) {
      return 0;
    }
    var limit = offset > content.length ? content.length : offset;
    var line = 1;
    for (i in 0...limit) {
      if (content.charCodeAt(i) == 10) {
        line++;
      }
    }
    return line;
  }

  function staticBool(expression:Expr):Null<Bool> {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EConst(CIdent("true")):
        true;
      case EConst(CIdent("false")):
        false;
      case ECall(callee, args) if (isStaticValueCall(callee)):
        if (args.length != 1) {
          Context.error("Quadrants Static.value expects one argument", expr.pos);
        }
        staticBool(args[0]);
      default:
        null;
    };
  }


  function requireIdent(expression:Expr, message:String):String {
    var expr = strip(expression);
    return switch (expr.expr) {
      case EConst(CIdent(name)): name;
      default: Context.error(message, expr.pos);
    }
  }

  function needsGradForDType(dtype:Int):Bool {
    return dtype == DTYPE_F16 || dtype == DTYPE_F32 || dtype == DTYPE_F64;
  }

  function parameterTypeInfo(type:Null<ComplexType>, pos:Position):{kind:Int, dtype:Int, needsGrad:Bool, spec:Bool} {
    if (type == null) {
      return {kind: PARAM_UNKNOWN, dtype: DTYPE_I32, needsGrad: false, spec: false};
    }
    return switch (type) {
      case TPath(path) if (isFieldPath(path)):
        var dtype = tensorElementDType(path, pos);
        {kind: PARAM_FIELD, dtype: dtype, needsGrad: needsGradForDType(dtype), spec: false};
      case TPath(path) if (isTensorPath(path)):
        var dtype = tensorElementDType(path, pos);
        {kind: PARAM_NDARRAY, dtype: dtype, needsGrad: needsGradForDType(dtype), spec: false};
      case TPath(path) if (isSpecPath(path)):
        {kind: PARAM_SCALAR, dtype: specElementDType(path, pos), needsGrad: false, spec: true};
      case TPath(path) if (isMeshAttributePath(path)):
        var dtype = meshAttributeValueDType(path, pos);
        {kind: PARAM_MESH_ATTRIBUTE, dtype: dtype, needsGrad: needsGradForDType(dtype), spec: false};
      case TPath(path) if (isQuantKernelParameterPath(path)):
        Context.error("Quadrants HashLink native quant kernel parameters require descriptor quant type metadata, which is not supported by this backend", pos);
      case TPath(path) if (isMeshKernelParameterPath(path)):
        Context.error("Quadrants HashLink kernel mesh domain/element parameters require descriptor mesh resource metadata; pass MeshRelation or MeshAttribute resources instead", pos);
      default:
        {kind: PARAM_SCALAR, dtype: dtypeFromComplexType(type, pos), needsGrad: false, spec: false};
    }
  }

  function isSpecPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Spec" || fullName == "quadrants.Spec";
  }

  function isTensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Tensor" || fullName == "quadrants.Tensor"
      || fullName == "VectorNdarray" || fullName == "quadrants.VectorNdarray"
      || fullName == "MatrixNdarray" || fullName == "quadrants.MatrixNdarray"
      || fullName == "VectorField" || fullName == "quadrants.VectorField"
      || fullName == "MatrixField" || fullName == "quadrants.MatrixField"
      || generatedTensorDType(path) != null;
  }

  function isFieldPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "Field" || fullName == "quadrants.Field"
      || fullName == "FieldArg" || fullName == "quadrants.FieldArg"
      || generatedFieldDType(path) != null;
  }

  function generatedTensorDType(path:TypePath):Null<Int> {
    var fullName = typePathName(path);
    var prefix = "quadrants._generated.Tensor_";
    if (StringTools.startsWith(fullName, prefix)) {
      return dtypeFromTypeName(fullName.substr(prefix.length), Context.currentPos(), DTYPE_F32);
    }
    return null;
  }

  function generatedFieldDType(path:TypePath):Null<Int> {
    var fullName = typePathName(path);
    var prefix = "quadrants._generated.Field_";
    if (StringTools.startsWith(fullName, prefix)) {
      return dtypeFromTypeName(fullName.substr(prefix.length), Context.currentPos(), DTYPE_F32);
    }
    return null;
  }

  function isQuantizedF32TensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "QuantizedF32Tensor" || fullName == "quadrants.quant.QuantizedF32Tensor";
  }

  function isQuantizedF32TensorComplexType(type:Null<ComplexType>):Bool {
    return switch (type) {
      case TPath(path): isQuantizedF32TensorPath(path);
      default: false;
    };
  }

  function isQuantKernelParameterPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "QuantStorageSpec" || fullName == "quadrants.quant.QuantStorageSpec"
      || fullName == "QuantInt" || fullName == "quadrants.quant.QuantInt"
      || fullName == "QuantFixed" || fullName == "quadrants.quant.QuantFixed"
      || fullName == "QuantFloat" || fullName == "quadrants.quant.QuantFloat";
  }

  function isMeshRelationPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "MeshRelation" || fullName == "quadrants.mesh.MeshRelation";
  }

  function isMeshAttributePath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "MeshAttribute" || fullName == "quadrants.mesh.MeshAttribute";
  }

  function isMeshRelationComplexType(type:Null<ComplexType>):Bool {
    return switch (type) {
      case TPath(path): isMeshRelationPath(path);
      default: false;
    };
  }

  function isMeshAttributeComplexType(type:Null<ComplexType>):Bool {
    return switch (type) {
      case TPath(path): isMeshAttributePath(path);
      default: false;
    };
  }

  function meshAttributeValueDType(path:TypePath, pos:Position):Int {
    if (path.params == null || path.params.length != 2) {
      Context.error("Quadrants MeshAttribute<Element, Value> requires element and value type parameters", pos);
    }
    return switch (path.params[1]) {
      case TPType(type): dtypeFromComplexType(type, pos, DTYPE_F32);
      default: Context.error("Quadrants MeshAttribute value parameter must be a dtype type", pos);
    };
  }

  function isMeshKernelParameterPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "MeshDomain" || fullName == "quadrants.mesh.MeshDomain"
      || fullName == "MeshElement" || fullName == "quadrants.mesh.MeshElement";
  }

  function structResourceInfo(name:String, type:Null<ComplexType>, pos:Position):Null<StructResourceInfo> {
    var kind = switch (type) {
      case TPath(path) if (isStructTensorPath(path)): PARAM_NDARRAY;
      case TPath(path) if (isStructFieldPath(path)): PARAM_FIELD;
      default: return null;
    };
    var structType = structResourceElementType(type, pos);
    var classRef = switch (Context.followWithAbstracts(structType)) {
      case TInst(ref, _): ref;
      default: Context.error("Quadrants StructTensor/StructField element type must be a QdStruct class", pos);
    };
    var cls = classRef.get();
    if (cls.meta.extract(":qdStruct").length == 0 && cls.meta.extract("qdStruct").length == 0) {
      Context.error('StructTensor/StructField element type ${cls.name} must use @:build(quadrants.macro.QdStruct.build())', pos);
    }
    var members = new Map<String, StructResourceMemberInfo>();
    var order:Array<String> = [];
    var sizeBytes = 0;
    var alignBytes = 1;
    var structName = (cls.pack.length == 0 ? "" : cls.pack.join(".") + ".") + cls.name;
    var layout = collectStructResourceMembers(cls, name, "", kind, 0, members, order, pos);
    sizeBytes = layout.offset;
    alignBytes = layout.align;
    if (order.length == 0) {
      Context.error('Quadrants QdStruct ${structName} has no kernel-visible fields', pos);
    }
    sizeBytes = alignToInt(sizeBytes, alignBytes);
    return {name: name, structName: structName, kind: kind, sizeBytes: sizeBytes, alignBytes: alignBytes, members: members, order: order};
  }

  function isStructTensorPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "StructTensor" || fullName == "quadrants.StructTensor";
  }

  function isStructFieldPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "StructField" || fullName == "quadrants.StructField";
  }

  function structResourceElementType(type:Null<ComplexType>, pos:Position):Type {
    return switch (type) {
      case TPath(path) if ((isStructTensorPath(path) || isStructFieldPath(path)) && path.params != null && path.params.length == 1):
        switch (path.params[0]) {
          case TPType(elementType): Context.resolveType(elementType, pos);
          default: Context.error("Quadrants StructTensor/StructField type parameter must be a QdStruct type", pos);
        }
      default:
        Context.error("Quadrants StructTensor/StructField parameter requires exactly one QdStruct type parameter", pos);
    };
  }

  function collectStructResourceMembers(cls:ClassType,
      rootName:String,
      prefix:String,
      kind:Int,
      offset:Int,
      members:Map<String, StructResourceMemberInfo>,
      order:Array<String>,
      pos:Position):{offset:Int, align:Int} {
    var currentOffset = offset;
    var maxAlign = 1;
    for (field in cls.fields.get()) {
      if (!field.isPublic) {
        continue;
      }
      var fieldType = TypeTools.toComplexType(field.type);
      var nested = nestedQdStructClass(fieldType, pos);
      if (nested != null) {
        var nestedLayout = collectStructResourceMembers(nested, rootName, prefix + field.name + ".", kind, currentOffset, members, order, pos);
        currentOffset = nestedLayout.offset;
        if (nestedLayout.align > maxAlign) maxAlign = nestedLayout.align;
        continue;
      }
      var fieldPath = prefix + field.name;
      var classified = qdStructMemberInfo(fieldPath, fieldType, pos, currentOffset);
      currentOffset = classified.offset + classified.size;
      if (classified.align > maxAlign) {
        maxAlign = classified.align;
      }
      var paramName = uniqueParameterName(rootName + "." + fieldPath);
      var paramId = params.length;
      params.push({name: paramName, kind: kind, rank: 0, dtype: classified.dtype, needsGrad: needsGradForDType(classified.dtype), rankFromShape: false, spec: false});
      if (classified.lanes == 1) {
        members[fieldPath] = {
          name: fieldPath,
          paramId: paramId,
          dtype: classified.dtype,
          lanes: 1,
          laneIndex: -1,
          offset: classified.offset,
          align: classified.align,
          size: classified.size,
        };
        order.push(fieldPath);
      } else {
        for (lane in 0...classified.lanes) {
          var laneName = fieldPath + "." + laneSuffix(fieldType, lane);
          members[laneName] = {
            name: laneName,
            paramId: paramId,
            dtype: classified.dtype,
            lanes: 1,
            laneIndex: lane,
            offset: classified.offset + lane * dtypeByteSizeForDescriptor(classified.dtype),
            align: classified.align,
            size: dtypeByteSizeForDescriptor(classified.dtype),
          };
          order.push(laneName);
        }
      }
    }
    return {offset: currentOffset, align: maxAlign};
  }

  function nestedQdStructClass(type:ComplexType, pos:Position):Null<ClassType> {
    return switch (Context.followWithAbstracts(Context.resolveType(type, pos))) {
      case TInst(classRef, _):
        var cls = classRef.get();
        cls.meta.extract(":qdStruct").length > 0 || cls.meta.extract("qdStruct").length > 0 ? cls : null;
      default:
        null;
    };
  }

  function laneSuffix(type:ComplexType, lane:Int):String {
    return switch (type) {
      case TPath(path) if (isVectorTypePath(path)):
        switch (lane) {
          case 0: "x";
          case 1: "y";
          case 2: "z";
          case 3: "w";
          default: Std.string(lane);
        }
      case TPath(path) if (isMatrixTypePath(path)):
        var rows = matrixRowsForTypeName(path.name);
        "m" + Std.string(Std.int(lane / rows)) + Std.string(lane % rows);
      default:
        Std.string(lane);
    };
  }

  function qdStructMemberInfo(name:String, type:ComplexType, pos:Position, nextOffset:Int):{dtype:Int, lanes:Int, offset:Int, align:Int, size:Int} {
    var lanes = 1;
    var dtype = switch (type) {
      case TPath(path) if (isVectorTypePath(path)):
        lanes = vectorLanesForTypeName(path.name);
        dtypeFromTypeParam(path, pos);
      case TPath(path) if (isMatrixTypePath(path)):
        lanes = matrixRowsForTypeName(path.name) * matrixRowsForTypeName(path.name);
        dtypeFromTypeParam(path, pos);
      default:
        dtypeFromComplexType(type, pos, DTYPE_F32);
    };
    var bytes = dtypeByteSizeForDescriptor(dtype);
    var align = bytes;
    var size = bytes * lanes;
    var offset = alignToInt(nextOffset, align);
    return {dtype: dtype, lanes: lanes, offset: offset, align: align, size: size};
  }

  function dtypeFromTypeParam(path:TypePath, pos:Position):Int {
    if (path.params == null || path.params.length == 0) {
      return DTYPE_F32;
    }
    if (path.params.length != 1) {
      Context.error('Quadrants ${path.name} QdStruct member requires zero or one dtype type parameter', pos);
    }
    return switch (path.params[0]) {
      case TPType(type): dtypeFromComplexType(type, pos, DTYPE_F32);
      default: Context.error('Quadrants ${path.name} QdStruct member type parameter must be a dtype type', pos);
    };
  }

  function isVectorTypePath(path:TypePath):Bool {
    return path.name == "Vec2" || path.name == "Vec3" || path.name == "Vec4";
  }

  function isMatrixTypePath(path:TypePath):Bool {
    return path.name == "Mat2" || path.name == "Mat3" || path.name == "Mat4";
  }

  function vectorLanesForTypeName(name:String):Int {
    return name == "Vec2" ? 2 : name == "Vec3" ? 3 : name == "Vec4" ? 4 : 1;
  }

  function matrixRowsForTypeName(name:String):Int {
    return name == "Mat2" ? 2 : name == "Mat3" ? 3 : name == "Mat4" ? 4 : 1;
  }

  function dtypeByteSizeForDescriptor(dtype:Int):Int {
    return switch (dtype) {
      case DTYPE_I8 | DTYPE_U8 | DTYPE_U1: 1;
      case DTYPE_I16 | DTYPE_U16 | DTYPE_F16: 2;
      case DTYPE_I32 | DTYPE_U32 | DTYPE_F32: 4;
      case DTYPE_I64 | DTYPE_U64 | DTYPE_F64: 8;
      default: 4;
    };
  }

  function alignToInt(value:Int, align:Int):Int {
    return align <= 1 ? value : Std.int((value + align - 1) / align) * align;
  }

  function isBufferViewComplexType(type:Null<ComplexType>):Bool {
    return switch (type) {
      case TPath(path): isBufferViewPath(path);
      default: false;
    };
  }

  function isBufferViewPath(path:TypePath):Bool {
    var fullName = typePathName(path);
    return fullName == "BufferView" || fullName == "quadrants.BufferView";
  }

  function bufferViewElementDType(type:Null<ComplexType>, pos:Position):Int {
    return switch (type) {
      case TPath(path) if (isBufferViewPath(path)):
        tensorElementDType(path, pos);
      default:
        Context.error("Quadrants BufferView parameter requires a BufferView<T> type", pos);
    };
  }

  function specElementDType(path:TypePath, pos:Position):Int {
    if (path.params == null || path.params.length != 1) {
      Context.error("Quadrants Spec<T> requires exactly one type parameter", pos);
    }
    return switch (path.params[0]) {
      case TPType(type): dtypeFromComplexType(type, pos);
      default: Context.error("Quadrants Spec<T> type parameter must be a type", pos);
    };
  }

  function tensorElementDType(path:TypePath, pos:Position):Int {
    var generated = generatedTensorDType(path);
    if (generated == null) {
      generated = generatedFieldDType(path);
    }
    if (generated != null) {
      return generated;
    }
    if (path.params == null || path.params.length == 0) {
      Context.error("Quadrants Tensor/Field kernel parameter requires an explicit dtype type parameter", pos);
    }
    return switch (path.params[0]) {
      case TPType(type): dtypeFromComplexType(type, pos, DTYPE_F32);
      default: Context.error("Quadrants Tensor type parameter must be a type", pos);
    }
  }

  function typePathName(path:TypePath):String {
    return (path.pack.length == 0 ? "" : path.pack.join(".") + ".") + path.name + (path.sub == null ? "" : "." + path.sub);
  }

  function dtypeFromTypeExpression(expression:Expr, pos:Position):Int {
    var expr = strip(expression);
    var fullName = switch (expr.expr) {
      case EConst(CIdent(name)): name;
      case EConst(CString(name, _)): name;
      case EField(_, _): callPath(expr, pos);
      default: Context.error("Quadrants HashLink bitCast target dtype must be a type name", pos);
    };
    return dtypeFromTypeName(fullName, pos);
  }

  function dtypeFromTypeName(fullName:String, pos:Position, floatDType:Int = DTYPE_F64):Int {
    return switch (fullName) {
      case "Int", "StdTypes.Int": DTYPE_I32;
      case "Bool", "StdTypes.Bool": DTYPE_U1;
      case "UInt", "StdTypes.UInt": DTYPE_U32;
      case "haxe.Int64", "Int64": DTYPE_I64;
      case "Float", "StdTypes.Float": floatDType;
      case "hl.F32", "F32": DTYPE_F32;
      case "quadrants.U1", "quadrants.Types.U1", "Types.U1", "U1": DTYPE_U1;
      case "quadrants.F16", "quadrants.Types.F16", "Types.F16", "F16": DTYPE_F16;
      case "quadrants.I8", "quadrants.Types.I8", "Types.I8", "I8": DTYPE_I8;
      case "quadrants.I16", "quadrants.Types.I16", "Types.I16", "I16": DTYPE_I16;
      case "quadrants.I32", "quadrants.Types.I32", "Types.I32", "I32": DTYPE_I32;
      case "quadrants.I64", "quadrants.Types.I64", "Types.I64", "I64": DTYPE_I64;
      case "quadrants.U8", "quadrants.Types.U8", "Types.U8", "U8": DTYPE_U8;
      case "quadrants.U16", "quadrants.Types.U16", "Types.U16", "U16": DTYPE_U16;
      case "quadrants.U32", "quadrants.Types.U32", "Types.U32", "U32": DTYPE_U32;
      case "quadrants.U64", "quadrants.Types.U64", "Types.U64", "U64": DTYPE_U64;
      case "quadrants.F32", "quadrants.Types.F32", "Types.F32": DTYPE_F32;
      case "quadrants.F64", "quadrants.Types.F64", "Types.F64", "F64": DTYPE_F64;
      default: Context.error('Unsupported Quadrants HashLink dtype ${fullName}', pos);
    };
  }

  function dtypeFromComplexType(type:Null<ComplexType>, pos:Position, floatDType:Int = DTYPE_F64):Int {
    if (type == null) {
      Context.error("Quadrants HashLink cast requires an explicit target type", pos);
    }
    return switch (type) {
      case TPath(path):
        dtypeFromTypeName(typePathName(path), pos, floatDType);
      default:
        Context.error("Unsupported Quadrants HashLink dtype", pos);
    }
  }

  static function stripNoCasts(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), EUntyped(inner), ECast(inner, null): stripNoCasts(inner);
      default: expression;
    }
  }

  public static function strip(expression:Expr):Expr {
    return switch (expression.expr) {
      case EParenthesis(inner), EMeta(_, inner), ECheckType(inner, _), ECast(inner, _), EUntyped(inner): strip(inner);
      default: expression;
    }
  }
}

class KernelBuilder {
  public static function build(ctx:Expr, fn:Expr, ?options:Expr):Expr {
    var functionExpr = unwrapMacroQuote(fn);
    var functionDef = switch (functionExpr.expr) {
      case EFunction(_, f): f;
      default: Context.error("quadrants.Kernel.build expects a macro arrow function", functionExpr.pos);
    };
    if (functionDef.expr == null) {
      Context.error("Quadrants HashLink kernel function must have a body", functionExpr.pos);
    }

    var kernelName = kernelNameFromOptions(options, functionExpr.pos);
    var builder = new DescriptorBuilder(functionDef.args, collectQdFunctions(options), kernelName, descriptorMetadataFromOptions(options));
    for (entry in boundaryClampFromOptions(options)) {
      builder.registerClampBoundary(entry.name, entry.pos);
    }
    var descriptorBytes = builder.build(functionDef.expr);
    var descriptorExpr = bytesExpression(descriptorBytes, functionExpr.pos);
    var autodiffMode = autodiffModeFromOptions(options);
    var graphLaunch = graphFromOptions(options);
    var reverseAutodiffReason = reverseAutodiffBlockedReason(functionDef.expr);
    if ((autodiffMode == 2 || autodiffMode == 3) && reverseAutodiffReason != null) {
      Context.error(reverseAutodiffReason, functionExpr.pos);
    }
    return macro quadrants.KernelRaw.fromDescriptor($e{ctx}, $e{descriptorExpr}, $v{descriptorBytes.length}, $v{autodiffMode}, $v{graphLaunch}, $v{kernelName}, $v{reverseAutodiffReason});
  }

  public static function buildRaw(ctx:Expr, fn:Expr, ?options:Expr):Expr {
    var functionExpr = unwrapMacroQuote(fn);
    var functionDef = switch (functionExpr.expr) {
      case EFunction(_, f): f;
      default: Context.error("quadrants.Kernel.buildRaw expects a macro arrow function", functionExpr.pos);
    };
    if (functionDef.expr == null) {
      Context.error("Quadrants HashLink kernel function must have a body", functionExpr.pos);
    }

    var kernelName = kernelNameFromOptions(options, functionExpr.pos);
    var builder = new DescriptorBuilder(functionDef.args, collectQdFunctions(options), kernelName, descriptorMetadataFromOptions(options));
    for (entry in boundaryClampFromOptions(options)) {
      builder.registerClampBoundary(entry.name, entry.pos);
    }
    var descriptorBytes = builder.build(functionDef.expr);
    var descriptorExpr = bytesExpression(descriptorBytes, functionExpr.pos);
    var autodiffMode = autodiffModeFromOptions(options);
    var graphLaunch = graphFromOptions(options);
    var reverseAutodiffReason = reverseAutodiffBlockedReason(functionDef.expr);
    if ((autodiffMode == 2 || autodiffMode == 3) && reverseAutodiffReason != null) {
      Context.error(reverseAutodiffReason, functionExpr.pos);
    }
    return macro quadrants.KernelRaw.fromDescriptor($e{ctx}, $e{descriptorExpr}, $v{descriptorBytes.length}, $v{autodiffMode}, $v{graphLaunch}, $v{kernelName}, $v{reverseAutodiffReason});
  }

  public static function descriptorBytes(fn:Expr, ?options:Expr):Expr {
    var functionExpr = unwrapMacroQuote(fn);
    var functionDef = switch (functionExpr.expr) {
      case EFunction(_, f): f;
      default: Context.error("quadrants.Kernel.descriptorBytes expects a macro arrow function", functionExpr.pos);
    };
    if (functionDef.expr == null) {
      Context.error("Quadrants HashLink kernel function must have a body", functionExpr.pos);
    }
    var builder = new DescriptorBuilder(functionDef.args, collectQdFunctions(options), kernelNameFromOptions(options, functionExpr.pos), descriptorMetadataFromOptions(options));
    for (entry in boundaryClampFromOptions(options)) {
      builder.registerClampBoundary(entry.name, entry.pos);
    }
    var descriptorBytes = builder.build(functionDef.expr);
    return bytesExpression(descriptorBytes, functionExpr.pos);
  }

  static function collectQdFunctions(?options:Expr):Map<String, QdFunctionInfo> {
    var functions = new Map<String, QdFunctionInfo>();
    for (helperClass in helperClassesFromOptions(options)) {
      collectClassQdFunctions(functions, helperClass.classType);
    }
    var localClass = Context.getLocalClass();
    if (localClass != null) {
      var local = localClass.get();
      for (helperClass in helperClassesFromMetadata(local)) {
        collectClassQdFunctions(functions, helperClass.classType);
      }
      collectClassQdFunctions(functions, local);
    }
    return functions;
  }

  static function collectClassQdFunctions(functions:Map<String, QdFunctionInfo>, classType:ClassType):Void {
    var owner = classTypeName(classType);
    for (field in classType.statics.get()) {
      if (field.meta.extract(":qdFunc").length == 0 && field.meta.extract("qdFunc").length == 0) {
        continue;
      }
      var typedExpr = field.expr();
      if (typedExpr == null) {
        Context.error('Quadrants qdFunc ${owner}.${field.name} has no function body', field.pos);
      }
      var expr = DescriptorBuilder.strip(Context.getTypedExpr(typedExpr));
      var functionDef = switch (expr.expr) {
        case EFunction(_, f):
          f;
        case EBlock(expressions) if (expressions.length == 1):
          switch (DescriptorBuilder.strip(expressions[0]).expr) {
            case EFunction(_, f): f;
            default: Context.error('Quadrants qdFunc ${owner}.${field.name} must be a static function', field.pos);
          }
        default:
          Context.error('Quadrants qdFunc ${owner}.${field.name} must be a static function', field.pos);
      };
      if (functionDef.expr == null) {
        Context.error('Quadrants qdFunc ${owner}.${field.name} must have a body', field.pos);
      }
      addQdFunction(functions, field.name, owner, functionDef, field.pos);
    }
  }

  static function addQdFunction(functions:Map<String, QdFunctionInfo>, name:String, owner:String, functionDef:Function, pos:Position):Void {
    var existing = functions.get(name);
    if (existing != null) {
      Context.error('Duplicate Quadrants qdFunc helper name ${name}: ${existing.owner}.${existing.name} and ${owner}.${name}; helper names must be unique', pos);
    }
    functions[name] = {name: name, owner: owner, args: functionDef.args, body: functionDef.expr, ret: functionDef.ret, pos: pos};
  }

  static function helperClassesFromOptions(options:Null<Expr>):Array<{classType:ClassType}> {
    if (options == null) {
      return [];
    }
    var expr = DescriptorBuilder.strip(options);
    if (isNullLiteral(expr)) {
      return [];
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        var helpers:Array<{classType:ClassType}> = [];
        for (field in fields) {
          if (field.field == "helpers") {
            helpers = helperClassList(field.expr);
          }
        }
        helpers;
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", expr.pos);
    };
  }

  static function helperClassesFromMetadata(classType:ClassType):Array<{classType:ClassType}> {
    var helpers:Array<{classType:ClassType}> = [];
    for (entry in classType.meta.extract(":qdHelpers").concat(classType.meta.extract("qdHelpers"))) {
      if (entry.params != null) {
        for (param in entry.params) {
          helpers.push(helperClass(param));
        }
      }
    }
    return helpers;
  }

  static function helperClassList(expr:Expr):Array<{classType:ClassType}> {
    var stripped = DescriptorBuilder.strip(expr);
    return switch (stripped.expr) {
      case EArrayDecl(values):
        [for (value in values) helperClass(value)];
      default:
        Context.error("quadrants.Kernel.build helpers option must be an array of class names", stripped.pos);
    };
  }

  static function helperClass(expr:Expr):{classType:ClassType} {
    var path = helperClassPath(expr);
    var type = try {
      Context.getType(path);
    } catch (_:Dynamic) {
      Context.error('Quadrants kernel helper class ${path} could not be resolved', expr.pos);
    };
    return switch (type) {
      case TInst(classRef, _):
        {classType: classRef.get()};
      default:
        Context.error('Quadrants kernel helper ${path} must be a class', expr.pos);
    };
  }

  static function helperClassPath(expr:Expr):String {
    var stripped = DescriptorBuilder.strip(expr);
    return switch (stripped.expr) {
      case EConst(CIdent(name)):
        name;
      case EField(base, field):
        helperClassPath(base) + "." + field;
      default:
        Context.error("quadrants.Kernel.build helpers option must contain class names", stripped.pos);
    };
  }

  static function classTypeName(classType:ClassType):String {
    return (classType.pack.length == 0 ? "" : classType.pack.join(".") + ".") + classType.name;
  }

  static function kernelNameFromOptions(options:Null<Expr>, pos:Position):String {
    if (options == null) {
      return kernelNameFromPosition(pos);
    }
    var expr = DescriptorBuilder.strip(options);
    if (isNullLiteral(expr)) {
      return kernelNameFromPosition(pos);
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        for (field in fields) {
          if (field.field == "name" || field.field == "debugName") {
            return stringLiteral(field.expr);
          }
        }
        kernelNameFromPosition(pos);
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", expr.pos);
    };
  }

  static function kernelNameFromPosition(pos:Position):String {
    var info = Context.getPosInfos(pos);
    var file = info.file;
    var slash = file.lastIndexOf("/");
    if (slash >= 0) {
      file = file.substr(slash + 1);
    }
    file = file.split(".").join("_");
    return 'haxe_kernel_${file}_${info.min}_${info.max}';
  }

  static function reverseAutodiffBlockedReason(functionBody:Expr):Null<String> {
    var writtenResources = new Map<String, Bool>();
    var reason:Null<String> = null;

    function setReason(message:String, pos:Position):Void {
      if (reason != null) {
        return;
      }
      var info = Context.getPosInfos(pos);
      reason = '${message} at ${info.file}:${info.min}';
    }

    function stripped(expr:Expr):Expr {
      return expr == null ? null : DescriptorBuilder.strip(expr);
    }

    function resourceRoot(expr:Expr):Null<String> {
      var clean = stripped(expr);
      if (clean == null) {
        return null;
      }
      return switch (clean.expr) {
        case EConst(CIdent(name)):
          name;
        case EField(base, _):
          resourceRoot(base);
        default:
          null;
      };
    }

    var visitRead:Expr->Void = null;

    function markWrite(target:Expr):Void {
      if (reason != null || target == null) {
        return;
      }
      var clean = stripped(target);
      switch (clean.expr) {
        case EArray(base, index):
          visitRead(index);
          var root = resourceRoot(base);
          if (root != null) {
            writtenResources.set(root, true);
          }
        case EParenthesis(inner) | EMeta(_, inner) | ECast(inner, _):
          markWrite(inner);
        case EField(_, _):
          // Struct local field writes are handled by native AD; only direct Tensor/Field resource writes are checked here.
        default:
          visitRead(clean);
      }
    }

    visitRead = function(expr:Expr):Void {
      if (reason != null || expr == null) {
        return;
      }
      var clean = stripped(expr);
      switch (clean.expr) {
        case EConst(_):
        case EArray(base, index):
          visitRead(index);
          var root = resourceRoot(base);
          if (root != null && writtenResources.exists(root)) {
            setReason('Quadrants autodiff validation detected read-after-write on resource ${root}; split the kernel or avoid reading a resource after writing it', clean.pos);
          } else {
            visitRead(base);
          }
        case EBinop(OpAssign, lhs, rhs):
          visitRead(rhs);
          markWrite(lhs);
        case EBinop(OpAssignOp(_), lhs, rhs):
          visitRead(rhs);
          markWrite(lhs);
        case EBinop(_, lhs, rhs):
          visitRead(lhs);
          visitRead(rhs);
        case EUnop(OpIncrement, _, target) | EUnop(OpDecrement, _, target):
          markWrite(target);
        case EUnop(_, _, target):
          visitRead(target);
        case EField(base, _):
          visitRead(base);
        case EParenthesis(inner) | EMeta(_, inner) | ECast(inner, _) | ECheckType(inner, _):
          visitRead(inner);
        case ECall(callee, args):
          visitRead(callee);
          for (arg in args) visitRead(arg);
        case ENew(_, args):
          for (arg in args) visitRead(arg);
        case EVars(vars):
          for (variable in vars) visitRead(variable.expr);
        case EBlock(expressions):
          for (entry in expressions) visitRead(entry);
        case EFor(iterator, body):
          visitRead(iterator);
          visitRead(body);
        case EWhile(_, _, _):
          setReason('Quadrants reverse/validation autodiff does not support dynamic while loops on the current backend', clean.pos);
        case EIf(cond, ifExpr, elseExpr):
          visitRead(cond);
          visitRead(ifExpr);
          visitRead(elseExpr);
        case ETernary(cond, ifExpr, elseExpr):
          visitRead(cond);
          visitRead(ifExpr);
          visitRead(elseExpr);
        case ESwitch(subject, cases, defaultExpr):
          visitRead(subject);
          for (caseExpr in cases) {
            for (value in caseExpr.values) visitRead(value);
            if (caseExpr.guard != null) visitRead(caseExpr.guard);
            visitRead(caseExpr.expr);
          }
          visitRead(defaultExpr);
        case ETry(body, catches):
          visitRead(body);
          for (catchExpr in catches) visitRead(catchExpr.expr);
        case EReturn(value):
          visitRead(value);
        case EThrow(value):
          visitRead(value);
        case EUntyped(value):
          visitRead(value);
        case EObjectDecl(fields):
          for (field in fields) visitRead(field.expr);
        case EArrayDecl(values):
          for (value in values) visitRead(value);
        case EFunction(_, _):
        case EBreak | EContinue:
        default:
      }
    };

    visitRead(functionBody);
    return reason;
  }



  static function autodiffModeFromOptions(options:Null<Expr>):Int {
    if (options == null) {
      return 0;
    }
    var expr = DescriptorBuilder.strip(options);
    if (isNullLiteral(expr)) {
      return 0;
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        var mode = 0;
        for (field in fields) {
          if (field.field == "autodiff") {
            mode = autodiffModeValue(field.expr);
          }
        }
        mode;
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", expr.pos);
    };
  }

  static function graphFromOptions(options:Null<Expr>):Bool {
    if (options == null) {
      return false;
    }
    var expr = DescriptorBuilder.strip(options);
    if (isNullLiteral(expr)) {
      return false;
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        var enabled = false;
        for (field in fields) {
          if (field.field == "graph") {
            enabled = boolLiteral(field.expr);
          }
        }
        enabled;
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", expr.pos);
    };
  }

  static function boundaryClampFromOptions(options:Null<Expr>):Array<{name:String, pos:Position}> {
    if (options == null) {
      return [];
    }
    var expr = DescriptorBuilder.strip(options);
    if (isNullLiteral(expr)) {
      return [];
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        var entries:Array<{name:String, pos:Position}> = [];
        for (field in fields) {
          if (field.field != "boundaryClamp") {
            continue;
          }
          switch (DescriptorBuilder.strip(field.expr).expr) {
            case EArrayDecl(values):
              for (value in values) {
                switch (DescriptorBuilder.strip(value).expr) {
                  case EConst(CString(name, _)):
                    entries.push({name: name, pos: value.pos});
                  default:
                    Context.error("quadrants.Kernel.build boundaryClamp option must be an array of parameter name strings", value.pos);
                }
              }
            default:
              Context.error("quadrants.Kernel.build boundaryClamp option must be an array of parameter name strings", field.expr.pos);
          }
        }
        entries;
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", expr.pos);
    };
  }

  static function descriptorMetadataFromOptions(options:Null<Expr>):Null<String> {
    if (options == null) {
      return null;
    }
    var expr = DescriptorBuilder.strip(options);
    if (isNullLiteral(expr)) {
      return null;
    }
    return switch (expr.expr) {
      case EObjectDecl(fields):
        for (field in fields) {
          if (field.field == "__qdhlMeta") {
            return stringLiteral(field.expr);
          }
        }
        null;
      default:
        Context.error("quadrants.Kernel.build options must be an object literal", expr.pos);
    };
  }

  static function autodiffModeValue(expr:Expr):Int {
    var stripped = DescriptorBuilder.strip(expr);
    return switch (stripped.expr) {
      case EConst(CIdent("None")):
        0;
      case EConst(CIdent("Forward")):
        1;
      case EConst(CIdent("Reverse")):
        2;
      case EConst(CIdent("Validate")):
        3;
      case EField(_, "None"):
        0;
      case EField(_, "Forward"):
        1;
      case EField(_, "Reverse"):
        2;
      case EField(_, "Validate"):
        3;
      default:
        Context.error("Unsupported Quadrants HashLink autodiff mode", stripped.pos);
    };
  }

  public static function decodeMacroExpr(expression:Expr):Expr {
    return unwrapMacroQuote(expression);
  }

  static function unwrapMacroQuote(expression:Expr):Expr {
    var expr = DescriptorBuilder.strip(expression);
    return switch (expr.expr) {
      case ECall({expr: EConst(CIdent("macro"))}, [quoted]): DescriptorBuilder.strip(quoted);
      case EObjectDecl(_): decodeQuotedExpr(expr);
      default: expr;
    };
  }

  static function decodeQuotedExpr(source:Expr):Expr {
    var exprField = objectField(source, "expr");
    if (exprField == null) {
      Context.error("Invalid quoted Haxe expression", source.pos);
    }
    var meta = constructorParts(exprField);
    if (meta != null && meta.name == "EMeta" && meta.params.length == 2) {
      return decodeQuotedExpr(meta.params[1]);
    }
    return {expr: decodeQuotedExprDef(exprField), pos: source.pos};
  }

  static function decodeQuotedExprDef(source:Expr):ExprDef {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe expression node", source.pos);
    }
    return switch (parts.name) {
      case "EConst":
        EConst(decodeQuotedConstant(parts.params[0]));
      case "EArray":
        EArray(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]));
      case "EBinop":
        EBinop(decodeQuotedBinop(parts.params[0]), decodeQuotedExpr(parts.params[1]), decodeQuotedExpr(parts.params[2]));
      case "EUnop":
        EUnop(decodeQuotedUnop(parts.params[0]), boolLiteral(parts.params[1]), decodeQuotedExpr(parts.params[2]));
      case "ECall":
        ECall(decodeQuotedExpr(parts.params[0]), [for (item in arrayElements(parts.params[1])) decodeQuotedExpr(item)]);
      case "EArrayDecl":
        EArrayDecl([for (item in arrayElements(parts.params[0])) decodeQuotedExpr(item)]);
      case "EObjectDecl":
        EObjectDecl([for (item in arrayElements(parts.params[0])) decodeQuotedObjectField(item)]);

      case "EField":
        EField(decodeQuotedExpr(parts.params[0]), stringLiteral(parts.params[1]));
      case "ECast":
        ECast(decodeQuotedExpr(parts.params[0]),
            parts.params.length >= 2 && !isNullLiteral(parts.params[1]) ? decodeQuotedComplexType(parts.params[1]) : null);
      case "ECheckType":
        ECheckType(decodeQuotedExpr(parts.params[0]), decodeQuotedComplexType(parts.params[1]));
      case "EBlock":
        EBlock([for (item in arrayElements(parts.params[0])) decodeQuotedExpr(item)]);
      case "EFor":
        EFor(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]));
      case "EWhile":
        EWhile(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]), boolLiteral(parts.params[2]));
      case "EBreak":
        EBreak;
      case "EContinue":
        EContinue;
      case "EVars":
        EVars([for (item in arrayElements(parts.params[0])) decodeQuotedVar(item)]);
      case "EIf":
        EIf(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]),
            parts.params.length >= 3 && !isNullLiteral(parts.params[2]) ? decodeQuotedExpr(parts.params[2]) : null);
      case "ETernary":
        ETernary(decodeQuotedExpr(parts.params[0]), decodeQuotedExpr(parts.params[1]), decodeQuotedExpr(parts.params[2]));
      case "EReturn":
        if (parts.params.length == 0 || isNullLiteral(parts.params[0])) {
          EReturn(null);
        } else {
          EReturn(decodeQuotedExpr(parts.params[0]));
        }
      case "EFunction":
        EFunction(decodeQuotedFunctionKind(parts.params[0]), decodeQuotedFunction(parts.params[1]));
      case "EParenthesis":
        EParenthesis(decodeQuotedExpr(parts.params[0]));
      case "ESwitch":
        ESwitch(decodeQuotedExpr(parts.params[0]),
            [for (item in arrayElements(parts.params[1])) decodeQuotedCase(item)],
            parts.params.length >= 3 && !isNullLiteral(parts.params[2]) ? decodeQuotedExpr(parts.params[2]) : null);
      default:
        Context.error('Unsupported quoted Haxe expression node ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedCase(source:Expr):Case {
    var valuesExpr = objectField(source, "values");
    if (valuesExpr == null) {
      Context.error("Quoted Haxe switch case is missing values", source.pos);
    }
    var guardExpr = objectField(source, "guard");
    var bodyExpr = objectField(source, "expr");
    return {
      values: [for (item in arrayElements(valuesExpr)) decodeQuotedExpr(item)],
      guard: guardExpr == null || isNullLiteral(guardExpr) ? null : decodeQuotedExpr(guardExpr),
      expr: bodyExpr == null || isNullLiteral(bodyExpr) ? null : decodeQuotedExpr(bodyExpr),
    };
  }

  static function decodeQuotedFunction(source:Expr):Function {
    var argsExpr = objectField(source, "args");
    if (argsExpr == null) {
      Context.error("Quoted Haxe function is missing args", source.pos);
    }
    var bodyExpr = objectField(source, "expr");
    var body = bodyExpr == null || isNullLiteral(bodyExpr) ? null : decodeQuotedExpr(bodyExpr);
    return {
      args: [for (arg in arrayElements(argsExpr)) decodeQuotedFunctionArg(arg)],
      ret: null,
      expr: body,
      params: null,
    };
  }

  static function decodeQuotedFunctionArg(source:Expr):FunctionArg {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe function argument is missing a name", source.pos);
    }
    var optExpr = objectField(source, "opt");
    var typeExpr = objectField(source, "type");
    var metaExpr = objectField(source, "meta");
    return {
      name: stringLiteral(nameExpr),
      opt: optExpr == null ? false : boolLiteral(optExpr),
      type: typeExpr == null || isNullLiteral(typeExpr) ? null : decodeQuotedComplexType(typeExpr),
      value: null,
      meta: metaExpr == null || isNullLiteral(metaExpr) ? null : [for (item in arrayElements(metaExpr)) decodeQuotedMetadataEntry(item)],
    };
  }

  static function decodeQuotedMetadataEntry(source:Expr):MetadataEntry {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe metadata entry is missing a name", source.pos);
    }
    var paramsExpr = objectField(source, "params");
    return {
      name: stringLiteral(nameExpr),
      params: paramsExpr == null || isNullLiteral(paramsExpr) ? [] : [for (item in arrayElements(paramsExpr)) decodeQuotedExpr(item)],
      pos: source.pos,
    };
  }

  static function decodeQuotedVar(source:Expr):Var {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe variable is missing a name", source.pos);
    }
    var expr = objectField(source, "expr");
    var typeExpr = objectField(source, "type");
    return {
      name: stringLiteral(nameExpr),
      type: typeExpr == null || isNullLiteral(typeExpr) ? null : decodeQuotedComplexType(typeExpr),
      expr: expr == null || isNullLiteral(expr) ? null : decodeQuotedExpr(expr),
      isFinal: false,
      meta: null,
    };
  }
  static function decodeQuotedObjectField(source:Expr):ObjectField {
    var fieldExpr = objectField(source, "field");
    if (fieldExpr == null) {
      Context.error("Quoted Haxe object field is missing a field name", source.pos);
    }
    var exprExpr = objectField(source, "expr");
    if (exprExpr == null) {
      Context.error("Quoted Haxe object field is missing an expression", source.pos);
    }
    return {
      field: stringLiteral(fieldExpr),
      expr: decodeQuotedExpr(exprExpr),
      quotes: null
    };
  }


  static function decodeQuotedFunctionKind(source:Expr):Null<FunctionKind> {
    return switch (constructorName(source)) {
      case "FArrow": FArrow;
      case "FAnonymous": FAnonymous;
      case "null": null;
      case other: Context.error('Unsupported quoted Haxe function kind ${other}', source.pos);
    };
  }

  static function decodeQuotedComplexType(source:Expr):ComplexType {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe complex type", source.pos);
    }
    return switch (parts.name) {
      case "TPath": TPath(decodeQuotedTypePath(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe complex type ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedTypePath(source:Expr):TypePath {
    var nameExpr = objectField(source, "name");
    if (nameExpr == null) {
      Context.error("Quoted Haxe type path is missing a name", source.pos);
    }
    var packExpr = objectField(source, "pack");
    var paramsExpr = objectField(source, "params");
    var subExpr = objectField(source, "sub");
    return {
      pack: packExpr == null ? [] : [for (item in arrayElements(packExpr)) stringLiteral(item)],
      name: stringLiteral(nameExpr),
      params: paramsExpr == null ? [] : [for (item in arrayElements(paramsExpr)) decodeQuotedTypeParam(item)],
      sub: subExpr == null || isNullLiteral(subExpr) ? null : stringLiteral(subExpr),
    };
  }

  static function decodeQuotedTypeParam(source:Expr):TypeParam {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe type parameter", source.pos);
    }
    return switch (parts.name) {
      case "TPType": TPType(decodeQuotedComplexType(parts.params[0]));
      case "TPExpr": TPExpr(decodeQuotedExpr(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe type parameter ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedConstant(source:Expr):Constant {
    var parts = constructorParts(source);
    if (parts == null) {
      Context.error("Invalid quoted Haxe constant", source.pos);
    }
    return switch (parts.name) {
      case "CInt": CInt(stringLiteral(parts.params[0]), null);
      case "CFloat": CFloat(stringLiteral(parts.params[0]), null);
      case "CIdent": CIdent(stringLiteral(parts.params[0]));
      case "CString": CString(stringLiteral(parts.params[0]));
      default: Context.error('Unsupported quoted Haxe constant ${parts.name}', source.pos);
    };
  }

  static function decodeQuotedBinop(source:Expr):Binop {
    var parts = constructorParts(source);
    if (parts != null && parts.name == "OpAssignOp") {
      return OpAssignOp(decodeQuotedBinop(parts.params[0]));
    }
    return switch (constructorName(source)) {
      case "OpAdd": OpAdd;
      case "OpSub": OpSub;
      case "OpMult": OpMult;
      case "OpDiv": OpDiv;
      case "OpMod": OpMod;
      case "OpEq": OpEq;
      case "OpNotEq": OpNotEq;
      case "OpLt": OpLt;
      case "OpLte": OpLte;
      case "OpGt": OpGt;
      case "OpGte": OpGte;
      case "OpBoolAnd": OpBoolAnd;
      case "OpBoolOr": OpBoolOr;
      case "OpAnd": OpAnd;
      case "OpOr": OpOr;
      case "OpXor": OpXor;
      case "OpShl": OpShl;
      case "OpShr": OpShr;
      case "OpUShr": OpUShr;
      case "OpAssign": OpAssign;
      case "OpInterval": OpInterval;
      case "OpIn": OpIn;
      case other: Context.error('Unsupported quoted Haxe binary operator ${other}', source.pos);
    };
  }

  static function decodeQuotedUnop(source:Expr):Unop {
    return switch (constructorName(source)) {
      case "OpNot": OpNot;
      case "OpNeg": OpNeg;
      case "OpNegBits": OpNegBits;
      case "OpIncrement": OpIncrement;
      case "OpDecrement": OpDecrement;
      case other: Context.error('Unsupported quoted Haxe unary operator ${other}', source.pos);
    };
  }

  static function constructorName(source:Expr):String {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CIdent(name)): name;
      case EField(_, field): field;
      default: Context.error("Invalid quoted Haxe enum constructor", source.pos);
    };
  }

  static function constructorParts(source:Expr):Null<{name:String, params:Array<Expr>}> {
    var expr = DescriptorBuilder.strip(source);
    return switch (expr.expr) {
      case ECall(callee, params): {name: constructorName(callee), params: params};
      case EConst(CIdent(_)) | EField(_, _): {name: constructorName(expr), params: []};
      default: null;
    };
  }

  static function objectField(source:Expr, name:String):Null<Expr> {
    return switch (DescriptorBuilder.strip(source).expr) {
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
    return switch (DescriptorBuilder.strip(source).expr) {
      case EArrayDecl(values): values;
      default: Context.error("Invalid quoted Haxe array", source.pos);
    };
  }

  static function stringLiteral(source:Expr):String {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CString(value, _)): value;
      default: Context.error("Expected quoted Haxe string literal", source.pos);
    };
  }

  static function boolLiteral(source:Expr):Bool {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CIdent("true")): true;
      case EConst(CIdent("false")): false;
      default: Context.error("Expected quoted Haxe bool literal", source.pos);
    };
  }

  static function isNullLiteral(source:Expr):Bool {
    return switch (DescriptorBuilder.strip(source).expr) {
      case EConst(CIdent("null")): true;
      default: false;
    };
  }

  static function bytesExpression(bytes:Array<Int>, pos:Position):Expr {
    var expressions:Array<Expr> = [];
    expressions.push(macro var descriptor = new hl.Bytes($v{bytes.length}));
    for (i in 0...bytes.length) {
      expressions.push(macro descriptor.setUI8($v{i}, $v{bytes[i]}));
    }
    expressions.push(macro descriptor);
    return {expr: EBlock(expressions), pos: pos};
  }
}
#end
