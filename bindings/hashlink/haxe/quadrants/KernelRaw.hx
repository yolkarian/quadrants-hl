package quadrants;

#if !macro
import quadrants.Native.QKernel;
import quadrants.Types.AutodiffMode;
import quadrants.Types.DType;
import quadrants.coverage.Coverage;
import quadrants.kernel.ArgBuffer;
#end

class KernelRaw {
  #if !macro
  final context:Context;
  final handle:QKernel;
  final descriptor:hl.Bytes;
  final descriptorLength:Int;
  final paramKinds:Array<Int>;
  final paramFlags:Array<Int>;
  final autodiffMode:AutodiffMode;
  final graphLaunchByDefault:Bool;
  final name:String;
  final reverseAutodiffBlockedReason:Null<String>;
  var closed:Bool = false;
  var descriptorHashCache:Null<String> = null;

  function new(context:Context,
      handle:QKernel,
      descriptor:hl.Bytes,
      descriptorLength:Int,
      autodiffMode:AutodiffMode,
      graphLaunchByDefault:Bool,
      name:String,
      reverseAutodiffBlockedReason:Null<String>) {
    this.context = context;
    this.handle = handle;
    this.descriptor = descriptor;
    this.descriptorLength = descriptorLength;
    this.paramKinds = decodeParamKinds(descriptor, descriptorLength);
    this.paramFlags = decodeParamFlags(descriptor, descriptorLength);
    this.autodiffMode = autodiffMode;
    this.graphLaunchByDefault = graphLaunchByDefault;
    this.name = name;
    this.reverseAutodiffBlockedReason = reverseAutodiffBlockedReason;
  }

  public static function fromDescriptor(context:Context,
      descriptor:hl.Bytes,
      ?descriptorLength:Int,
      autodiffMode:AutodiffMode = None,
      graphLaunchByDefault:Bool = false,
      kernelName:String = "haxe_kernel",
      reverseAutodiffBlockedReason:Null<String> = null):KernelRaw {
    if ((autodiffMode == Reverse || autodiffMode == Validate) && reverseAutodiffBlockedReason != null) {
      throw reverseAutodiffBlockedReason;
    }
    if (descriptorLength == null) {
      throw "Quadrants descriptor length is required for raw hl.Bytes descriptors";
    }
    var kernel = new KernelRaw(context,
      Native.kernel_compile(context.nativeHandle(), descriptor, descriptorLength, autodiffMode),
      descriptor,
      descriptorLength,
      autodiffMode,
      graphLaunchByDefault,
      kernelName,
      reverseAutodiffBlockedReason);
    if (Coverage.enabled) {
      Coverage.registerKernelBuild(kernel);
    }
    return kernel;
  }

  public function kernelName():String {
    return name;
  }

  public function descriptorLengthBytes():Int {
    return descriptorLength;
  }

  public function descriptorByteAt(index:Int):Int {
    if (index < 0 || index >= descriptorLength) {
      throw "Quadrants descriptor byte index is out of range";
    }
    return descriptor.getUI8(index);
  }

  public function autodiffModeValue():AutodiffMode {
    return autodiffMode;
  }

  public function graphLaunchByDefaultEnabled():Bool {
    return graphLaunchByDefault;
  }

  public function reverseAutodiffReason():Null<String> {
    return reverseAutodiffBlockedReason;
  }

  public function isClosed():Bool {
    return closed;
  }
  #end

  public static macro function build(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.buildRaw(ctx, fn, options);
  }

  #if !macro
  static inline var PARAM_KIND_NDARRAY = 1;
  static inline var PARAM_KIND_FIELD = 2;
  static inline var PARAM_KIND_MESH_ATTRIBUTE = 4;
  static inline var PARAM_FLAG_SPEC = 2;
  static inline var SECTION_TYPE_TABLE = 11;
  static inline var SECTION_ARG_TABLE = 15;

  static inline function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static function sectionRange(descriptor:hl.Bytes, kind:Int):Null<{offset:Int, length:Int}> {
    var sectionCount = u32(descriptor, 8);
    var tableOffset = u32(descriptor, 12);
    for (section in 0...sectionCount) {
      var entry = tableOffset + section * 12;
      if (u32(descriptor, entry) == kind) {
        return {offset: u32(descriptor, entry + 4), length: u32(descriptor, entry + 8)};
      }
    }
    return null;
  }

  static function canonicalParamKind(typeKind:Int):Int {
    return switch (typeKind) {
      case 0 | 1: 0;
      case 2 | 4 | 8: 1;
      case 3 | 5: 2;
      case 6: 3;
      case 7: 4;
      default: throw 'Quadrants descriptor TypeTable kind ${typeKind} is not a supported kernel parameter kind';
    };
  }

  static function decodeParamByte(descriptor:hl.Bytes, byteOffsetInEntry:Int):Array<Int> {
    var typeRange = sectionRange(descriptor, SECTION_TYPE_TABLE);
    var argRange = sectionRange(descriptor, SECTION_ARG_TABLE);
    if (typeRange == null || argRange == null) {
      throw "Quadrants v3 descriptor is missing canonical TypeTable/ArgTable sections";
    }

    var typeKinds = new Map<Int, Int>();
    var typeFlags = new Map<Int, Int>();
    var typeCount = u32(descriptor, typeRange.offset);
    var typeOffset = typeRange.offset + 4;
    for (_ in 0...typeCount) {
      var id = u32(descriptor, typeOffset);
      typeKinds[id] = descriptor.getUI8(typeOffset + 4);
      typeFlags[id] = descriptor.getUI8(typeOffset + 7);
      typeOffset += 16;
    }

    var count = u32(descriptor, argRange.offset);
    var values = [for (_ in 0...count) 0];
    var offset = argRange.offset + 4;
    for (_ in 0...count) {
      var paramIndex = u32(descriptor, offset);
      var typeId = u32(descriptor, offset + 4);
      var typeKind = typeKinds.get(typeId);
      if (typeKind == null || paramIndex < 0 || paramIndex >= values.length) {
        throw "Quadrants v3 descriptor ArgTable is invalid";
      }
      if (byteOffsetInEntry == 0) {
        values[paramIndex] = canonicalParamKind(typeKind);
      } else if (byteOffsetInEntry == 3) {
        var flags = typeFlags.get(typeId);
        values[paramIndex] = (flags == null ? 0 : flags) | descriptor.getUI8(offset + 13);
      } else {
        values[paramIndex] = 0;
      }
      offset += 16;
    }
    return values;
  }

  static function decodeParamKinds(descriptor:hl.Bytes, descriptorLength:Int):Array<Int> {
    return decodeParamByte(descriptor, 0);
  }

  static function decodeParamFlags(descriptor:hl.Bytes, descriptorLength:Int):Array<Int> {
    return decodeParamByte(descriptor, 3);
  }

  static function dtypeByteSize(dtype:DType):Int {
    return switch (dtype) {
      case DType.I8 | DType.U8 | DType.U1:
        1;
      case DType.I16 | DType.U16 | DType.F16:
        2;
      case DType.I32 | DType.U32 | DType.F32:
        4;
      case DType.I64 | DType.U64 | DType.F64:
        8;
    };
  }

  inline function paramKindAt(index:Int):Int {
    return index >= 0 && index < paramKinds.length ? paramKinds[index] : PARAM_KIND_NDARRAY;
  }

  inline function paramIsSpec(index:Int):Bool {
    return index >= 0 && index < paramFlags.length && (paramFlags[index] & PARAM_FLAG_SPEC) != 0;
  }

  function nativeArray(values:Array<Dynamic>):hl.NativeArray<Dynamic> {
    var native = new hl.NativeArray<Dynamic>(values.length);
    for (i in 0...values.length) {
      native[i] = values[i];
    }
    return native;
  }

  function splitFullArgs(values:Array<Dynamic>):{runtime:Array<Dynamic>, specs:Array<Dynamic>} {
    var runtime:Array<Dynamic> = [];
    var specs:Array<Dynamic> = [];
    var paramIndex = 0;
    for (value in values) {
      if (paramIsSpec(paramIndex)) {
        specs.push(value);
        paramIndex++;
      } else {
        runtime.push(value);
        paramIndex += Std.isOfType(value, BufferView) ? 3 : (Reflect.field(value, "__qdQuantStorage") != null ? 4 : 1);
      }
    }
    return {runtime: runtime, specs: specs};
  }

  function nativeRuntimeArgs(values:Array<Dynamic>):hl.NativeArray<Dynamic> {
    var flattened:Array<Dynamic> = [];
    var paramIndex = 0;
    var valueIndex = 0;
    while (paramIndex < paramKinds.length) {
      if (paramIsSpec(paramIndex)) {
        paramIndex++;
        continue;
      }
      if (valueIndex >= values.length) {
        throw "Quadrants kernel runtime argument count mismatch";
      }
      var value = values[valueIndex++];
      if (Std.isOfType(value, BufferView)) {
        var view:BufferView<Dynamic> = cast value;
        flattened.push(view.tensor.nativeHandle());
        flattened.push(view.flatStart);
        flattened.push(view.length);
        paramIndex += 3;
      } else if (Reflect.field(value, "__qdNativeRelation") != null) {
        flattened.push(Reflect.callMethod(value, Reflect.field(value, "__qdNativeRelation"), [context]));
        paramIndex++;
      } else if (Reflect.field(value, "__qdAttributeStorage") != null) {
        var storage:Dynamic = Reflect.callMethod(value, Reflect.field(value, "__qdAttributeStorage"), []);
        var field:FieldRuntime = cast storage;
        if (paramKindAt(paramIndex) != PARAM_KIND_FIELD && paramKindAt(paramIndex) != PARAM_KIND_MESH_ATTRIBUTE) {
          throw "MeshAttribute kernel parameter requires a Field-backed attribute resource";
        }
        if (!field.hasSNode()) {
          throw "Quadrants MeshAttribute kernel arguments must use placed Field storage";
        }
        flattened.push(field.snodeId);
        paramIndex++;
      } else if (Reflect.field(value, "__qdQuantStorage") != null) {
        var storage:Dynamic = Reflect.callMethod(value, Reflect.field(value, "__qdQuantStorage"), []);
        flattened.push(storage.nativeHandle());
        flattened.push(Reflect.callMethod(value, Reflect.field(value, "__qdQuantScale"), []));
        flattened.push(Reflect.callMethod(value, Reflect.field(value, "__qdQuantMinRaw"), []));
        flattened.push(Reflect.callMethod(value, Reflect.field(value, "__qdQuantMaxRaw"), []));
        paramIndex += 4;
      } else if (Std.isOfType(value, FieldRuntime)) {
        var field:FieldRuntime = cast value;
        if (paramKindAt(paramIndex) != PARAM_KIND_FIELD) {
          throw "Field<T> parameter requires capability field_resource_param. Current descriptor expects a Tensor resource; pass a Tensor<T> explicitly instead of relying on the removed Field mirror path.";
        }
        if (!field.hasSNode()) {
          throw "Quadrants Field kernel arguments must be placed SNode fields";
        }
        flattened.push(field.snodeId);
        paramIndex++;
      } else if (Std.isOfType(value, TensorHandle)) {
        var tensor:TensorHandle = cast value;
        flattened.push(tensor.nativeHandle());
        paramIndex++;
      } else {
        flattened.push(value);
        paramIndex++;
      }
    }
    if (valueIndex != values.length) {
      throw "Quadrants kernel runtime argument count mismatch";
    }
    return nativeArray(flattened);
  }

  function callOptionalSync(value:Dynamic, methodName:String):Void {
    var method = Reflect.field(value, methodName);
    if (method != null) {
      Reflect.callMethod(value, method, []);
    }
  }

  function syncFieldArgsToTensor(values:Array<Dynamic>):Void {
    for (value in values) {
      if (!Std.isOfType(value, FieldRuntime)) {
        callOptionalSync(value, "syncBeforeKernel");
      }
    }
  }

  function syncFieldArgsFromTensor(values:Array<Dynamic>):Void {
    var paramIndex = 0;
    for (value in values) {
      if (Std.isOfType(value, BufferView)) {
        paramIndex += 3;
      } else if (Std.isOfType(value, FieldRuntime)) {
        paramIndex++;
      } else {
        callOptionalSync(value, "syncAfterKernel");
        paramIndex++;
      }
    }
  }

  function requireOpen():Void {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
  }

  function requireReverseAutodiffSupport():Void {
    if (reverseAutodiffBlockedReason != null) {
      throw reverseAutodiffBlockedReason;
    }
  }

  function requireGraphWhileControl(values:Array<Dynamic>, controlArgId:Int):Dynamic {
    if (controlArgId < 0 || controlArgId >= values.length) {
      throw "Quadrants graph_while control argument index is out of range";
    }
    var value = values[controlArgId];
    if (!Std.isOfType(value, TensorHandle)) {
      throw "Quadrants graph_while control argument must be an I32 Tensor or Field";
    }
    var tensor:TensorHandle = cast value;
    if (tensor.dtype != DType.I32) {
      throw "Quadrants graph_while control argument must be an I32 Tensor or Field";
    }
    var readMethod = Reflect.field(value, "read");
    if (readMethod == null) {
      throw "Quadrants graph_while control argument must expose read(0)";
    }
    return value;
  }

  function readGraphWhileControl(control:Dynamic):Int {
    var readMethod = Reflect.field(control, "read");
    return Reflect.callMethod(control, readMethod, [0]);
  }

  function runtimeLaunchArgIdForFullValueIndex(values:Array<Dynamic>, controlArgId:Int):Int {
    var paramIndex = 0;
    var runtimeArgId = 0;
    for (valueIndex in 0...values.length) {
      if (paramIsSpec(paramIndex)) {
        if (valueIndex == controlArgId) {
          throw "Quadrants graph_do_while control argument cannot be a Spec<T> parameter";
        }
        paramIndex++;
        continue;
      }
      if (valueIndex == controlArgId) {
        return runtimeArgId;
      }
      var width = Std.isOfType(values[valueIndex], BufferView) ? 3 : (Reflect.field(values[valueIndex], "__qdQuantStorage") != null ? 4 : 1);
      paramIndex += width;
      runtimeArgId += width;
    }
    throw "Quadrants graph_do_while control argument index is out of range";
  }

  function recordCoverageLaunch(kind:String):Void {
    if (Coverage.enabled) {
      Coverage.registerKernelLaunch(this, kind);
    }
  }

  public function launchDynamic(values:Array<Dynamic>):Void {
    var split = splitFullArgs(values);
    launchSpecialized(split.runtime, split.specs, graphLaunchByDefault ? "launchGraphDefault" : "launch", graphLaunchByDefault);
  }

  public function launchRetDynamic(values:Array<Dynamic>):Dynamic {
    var split = splitFullArgs(values);
    return launchRetSpecialized(split.runtime, split.specs);
  }

  public function launchRetsDynamic(values:Array<Dynamic>):hl.NativeArray<Dynamic> {
    var split = splitFullArgs(values);
    return launchRetsSpecialized(split.runtime, split.specs);
  }

  public function launchOnDynamic(stream:Stream, values:Array<Dynamic>):Void {
    var split = splitFullArgs(values);
    launchOnSpecialized(stream, split.runtime, split.specs);
  }

  public function launchGraphDynamic(values:Array<Dynamic>):Void {
    var split = splitFullArgs(values);
    launchSpecialized(split.runtime, split.specs, "launchGraph", true);
  }

  public function launchGraphWhileDynamic(controlArgId:Int, values:Array<Dynamic>):Void {
    requireOpen();
    var control = requireGraphWhileControl(values, controlArgId);
    var split = splitFullArgs(values);
    while (readGraphWhileControl(control) != 0) {
      launchSpecialized(split.runtime, split.specs, "launchGraphWhile", true);
      context.sync();
    }
  }

  public function launchGraphDoWhileDynamic(controlArgId:Int, values:Array<Dynamic>):Void {
    var runtimeControlArgId = runtimeLaunchArgIdForFullValueIndex(values, controlArgId);
    var split = splitFullArgs(values);
    launchGraphDoWhileSpecialized(runtimeControlArgId, split.runtime, split.specs);
  }

  public function launchBuffer(buf:ArgBuffer):Void {
    launchSpecialized(buf.toArray(), buf.specArray(), graphLaunchByDefault ? "launchGraphDefault" : "launch", graphLaunchByDefault);
  }

  public function launchOnBuffer(stream:Stream, buf:ArgBuffer):Void {
    launchOnSpecialized(stream, buf.toArray(), buf.specArray());
  }

  public function launchGraphBuffer(buf:ArgBuffer):Void {
    launchSpecialized(buf.toArray(), buf.specArray(), "launchGraph", true);
  }

  public function launchRetBuffer(buf:ArgBuffer):Dynamic {
    return launchRetSpecialized(buf.toArray(), buf.specArray());
  }

  public function launchRetsBuffer(buf:ArgBuffer):hl.NativeArray<Dynamic> {
    return launchRetsSpecialized(buf.toArray(), buf.specArray());
  }

  function launchSpecialized(runtimeValues:Array<Dynamic>, specValues:Array<Dynamic>, coverageKind:String, graph:Bool):Void {
    requireOpen();
    syncFieldArgsToTensor(runtimeValues);
    if (graph) {
      Native.kernel_launch_graph_specialized(context.nativeHandle(), handle, nativeRuntimeArgs(runtimeValues), nativeArray(specValues));
    } else {
      Native.kernel_launch_specialized(context.nativeHandle(), handle, nativeRuntimeArgs(runtimeValues), nativeArray(specValues));
    }
    syncFieldArgsFromTensor(runtimeValues);
    recordCoverageLaunch(coverageKind);
  }

  function launchOnSpecialized(stream:Stream, runtimeValues:Array<Dynamic>, specValues:Array<Dynamic>):Void {
    requireOpen();
    syncFieldArgsToTensor(runtimeValues);
    Native.kernel_launch_on_specialized(context.nativeHandle(), handle, stream.nativeHandle(), nativeRuntimeArgs(runtimeValues), nativeArray(specValues));
    syncFieldArgsFromTensor(runtimeValues);
    recordCoverageLaunch("launchOn");
  }

  function launchGraphDoWhileSpecialized(controlArgId:Int, runtimeValues:Array<Dynamic>, specValues:Array<Dynamic>):Void {
    requireOpen();
    syncFieldArgsToTensor(runtimeValues);
    Native.kernel_launch_graph_do_while_specialized(context.nativeHandle(), handle, controlArgId, nativeRuntimeArgs(runtimeValues), nativeArray(specValues));
    syncFieldArgsFromTensor(runtimeValues);
    recordCoverageLaunch("launchGraphDoWhile");
  }

  function launchRetSpecialized(runtimeValues:Array<Dynamic>, specValues:Array<Dynamic>):Dynamic {
    requireOpen();
    syncFieldArgsToTensor(runtimeValues);
    var result = Native.kernel_launch_ret_specialized(context.nativeHandle(), handle, nativeRuntimeArgs(runtimeValues), nativeArray(specValues));
    syncFieldArgsFromTensor(runtimeValues);
    recordCoverageLaunch("launchRet");
    return result;
  }

  function launchRetsSpecialized(runtimeValues:Array<Dynamic>, specValues:Array<Dynamic>):hl.NativeArray<Dynamic> {
    requireOpen();
    syncFieldArgsToTensor(runtimeValues);
    var result = Native.kernel_launch_rets_specialized(context.nativeHandle(), handle, nativeRuntimeArgs(runtimeValues), nativeArray(specValues));
    syncFieldArgsFromTensor(runtimeValues);
    recordCoverageLaunch("launchRets");
    return result;
  }

  public function descriptorHash():String {
    if (descriptorHashCache == null) {
      var hash = 0x811c9dc5;
      for (i in 0...descriptorLength) {
        hash = (hash ^ descriptor.getUI8(i)) * 0x01000193;
      }
      descriptorHashCache = StringTools.hex(hash, 8);
    }
    return descriptorHashCache;
  }

  public function grad():KernelRaw {
    requireOpen();
    requireReverseAutodiffSupport();
    return fromDescriptor(context, descriptor, descriptorLength, Reverse, graphLaunchByDefault, name, reverseAutodiffBlockedReason);
  }

  public function forwardGrad():KernelRaw {
    requireOpen();
    return fromDescriptor(context, descriptor, descriptorLength, Forward, graphLaunchByDefault, name, reverseAutodiffBlockedReason);
  }

  public function validationKernel():KernelRaw {
    requireOpen();
    requireReverseAutodiffSupport();
    return fromDescriptor(context, descriptor, descriptorLength, Validate, graphLaunchByDefault, name, reverseAutodiffBlockedReason);
  }

  public function close():Void {
    if (!closed) {
      Native.kernel_close(handle);
      closed = true;
    }
  }
  #end
}
