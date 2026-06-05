package quadrants;

#if !macro
import quadrants.Native.QKernel;
import quadrants.Types.AutodiffMode;
import quadrants.Types.DType;
import quadrants.coverage.Coverage;
#end

class Kernel {
  #if !macro
  final context:Context;
  final handle:QKernel;
  final descriptor:hl.Bytes;
  final descriptorLength:Int;
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
      reverseAutodiffBlockedReason:Null<String> = null):Kernel {
    if ((autodiffMode == Reverse || autodiffMode == Validate) && reverseAutodiffBlockedReason != null) {
      throw reverseAutodiffBlockedReason;
    }
    if (descriptorLength == null) {
      throw "Quadrants descriptor length is required for raw hl.Bytes descriptors";
    }
    var kernel = new Kernel(context,
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
    return quadrants.macro.KernelBuilder.build(ctx, fn, options);
  }

  public static macro function descriptorBytes(fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.descriptorBytes(fn, options);
  }

  #if !macro
  function nativeArgs(values:Array<Dynamic>):hl.NativeArray<Dynamic> {
    var flattened:Array<Dynamic> = [];
    for (value in values) {
      if (Std.isOfType(value, BufferView)) {
        var view:BufferView<Dynamic> = cast value;
        flattened.push(view.tensor.nativeHandle());
        flattened.push(view.flatStart);
        flattened.push(view.length);
      } else if (Std.isOfType(value, TensorHandle)) {
        var tensor:TensorHandle = cast value;
        flattened.push(tensor.nativeHandle());
      } else {
        flattened.push(value);
      }
    }
    var nativeArgs = new hl.NativeArray<Dynamic>(flattened.length);
    for (i in 0...flattened.length) {
      nativeArgs[i] = flattened[i];
    }
    return nativeArgs;
  }


  function callOptionalSync(value:Dynamic, methodName:String):Void {
    var method = Reflect.field(value, methodName);
    if (method != null) {
      Reflect.callMethod(value, method, []);
    }
  }

  function syncFieldArgsToTensor(values:Array<Dynamic>):Void {
    for (value in values) {
      if (Std.isOfType(value, FieldRuntime)) {
        var field = (cast value : FieldRuntime);
        field.syncSNodeToTensor();
        field.syncAutodiffPeersToTensor();
      } else {
        callOptionalSync(value, "syncBeforeKernel");
      }
    }
  }

  function syncFieldArgsFromTensor(values:Array<Dynamic>):Void {
    for (value in values) {
      if (Std.isOfType(value, FieldRuntime)) {
        var field = (cast value : FieldRuntime);
        field.syncTensorToSNode();
        field.syncAutodiffPeersFromTensor();
      } else {
        callOptionalSync(value, "syncAfterKernel");
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

  function recordCoverageLaunch(kind:String):Void {
    if (Coverage.enabled) {
      Coverage.registerKernelLaunch(this, kind);
    }
  }

  public function launch(...values:Dynamic):Void {
    requireOpen();
    syncFieldArgsToTensor(values);
    if (graphLaunchByDefault) {
      Native.kernel_launch_graph(context.nativeHandle(), handle, nativeArgs(values));
    } else {
      Native.kernel_launch(context.nativeHandle(), handle, nativeArgs(values));
    }
    syncFieldArgsFromTensor(values);
    recordCoverageLaunch(graphLaunchByDefault ? "launchGraphDefault" : "launch");
  }

  public function launchRet(...values:Dynamic):Dynamic {
    requireOpen();
    syncFieldArgsToTensor(values);
    var result = Native.kernel_launch_ret(context.nativeHandle(), handle, nativeArgs(values));
    syncFieldArgsFromTensor(values);
    recordCoverageLaunch("launchRet");
    return result;
  }

  public function launchRets(...values:Dynamic):hl.NativeArray<Dynamic> {
    requireOpen();
    syncFieldArgsToTensor(values);
    var result = Native.kernel_launch_rets(context.nativeHandle(), handle, nativeArgs(values));
    syncFieldArgsFromTensor(values);
    recordCoverageLaunch("launchRets");
    return result;
  }

  public function launchOn(stream:Stream, ...values:Dynamic):Void {
    requireOpen();
    syncFieldArgsToTensor(values);
    Native.kernel_launch_on(context.nativeHandle(), handle, stream.nativeHandle(), nativeArgs(values));
    syncFieldArgsFromTensor(values);
    recordCoverageLaunch("launchOn");
  }

  public function launchGraph(...values:Dynamic):Void {
    requireOpen();
    syncFieldArgsToTensor(values);
    Native.kernel_launch_graph(context.nativeHandle(), handle, nativeArgs(values));
    syncFieldArgsFromTensor(values);
    recordCoverageLaunch("launchGraph");
  }

  public function launchGraphWhile(controlArgId:Int, ...values:Dynamic):Void {
    requireOpen();
    var control = requireGraphWhileControl(values, controlArgId);
    while (readGraphWhileControl(control) != 0) {
      syncFieldArgsToTensor(values);
      Native.kernel_launch_graph(context.nativeHandle(), handle, nativeArgs(values));
      syncFieldArgsFromTensor(values);
      context.sync();
      recordCoverageLaunch("launchGraphWhile");
    }
  }

  public function launchGraphDoWhile(controlArgId:Int, ...values:Dynamic):Void {
    requireOpen();
    syncFieldArgsToTensor(values);
    Native.kernel_launch_graph_do_while(context.nativeHandle(), handle, controlArgId, nativeArgs(values));
    syncFieldArgsFromTensor(values);
    recordCoverageLaunch("launchGraphDoWhile");
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

  public function grad():Kernel {
    requireOpen();
    requireReverseAutodiffSupport();
    return fromDescriptor(context, descriptor, descriptorLength, Reverse, graphLaunchByDefault, name, reverseAutodiffBlockedReason);
  }

  public function forwardGrad():Kernel {
    requireOpen();
    return fromDescriptor(context, descriptor, descriptorLength, Forward, graphLaunchByDefault, name, reverseAutodiffBlockedReason);
  }

  public function validationKernel():Kernel {
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
