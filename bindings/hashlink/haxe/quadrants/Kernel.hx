package quadrants;

#if !macro
import quadrants.Native.QKernel;
import quadrants.Types.AutodiffMode;
#end

class Kernel {
  #if !macro
  final context:Context;
  final handle:QKernel;
  final descriptor:hl.Bytes;
  final descriptorLength:Int;
  final autodiffMode:AutodiffMode;
  final graphLaunchByDefault:Bool;
  var closed:Bool = false;

  function new(context:Context, handle:QKernel, descriptor:hl.Bytes, descriptorLength:Int, autodiffMode:AutodiffMode, graphLaunchByDefault:Bool) {
    this.context = context;
    this.handle = handle;
    this.descriptor = descriptor;
    this.descriptorLength = descriptorLength;
    this.autodiffMode = autodiffMode;
    this.graphLaunchByDefault = graphLaunchByDefault;
  }

  public static function fromDescriptor(context:Context, descriptor:hl.Bytes, ?descriptorLength:Int, autodiffMode:AutodiffMode = None, graphLaunchByDefault:Bool = false):Kernel {
    if (descriptorLength == null) {
      throw "Quadrants descriptor length is required for raw hl.Bytes descriptors";
    }
    return new Kernel(context, Native.kernel_compile(context.nativeHandle(), descriptor, descriptorLength, autodiffMode),
        descriptor, descriptorLength, autodiffMode, graphLaunchByDefault);
  }
  #end

  public static macro function build(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.build(ctx, fn, options);
  }

  public static macro function descriptorBytes(fn:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.descriptorBytes(fn);
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

  function syncFieldArgsToTensor(values:Array<Dynamic>):Void {
    for (value in values) {
      if (Std.isOfType(value, FieldRuntime)) {
        (cast value : FieldRuntime).syncSNodeToTensor();
      }
    }
  }

  function syncFieldArgsFromTensor(values:Array<Dynamic>):Void {
    for (value in values) {
      if (Std.isOfType(value, FieldRuntime)) {
        (cast value : FieldRuntime).syncTensorToSNode();
      }
    }
  }

  public function launch(...values:Dynamic):Void {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    syncFieldArgsToTensor(values);
    if (graphLaunchByDefault) {
      Native.kernel_launch_graph(context.nativeHandle(), handle, nativeArgs(values));
    } else {
      Native.kernel_launch(context.nativeHandle(), handle, nativeArgs(values));
    }
    syncFieldArgsFromTensor(values);
  }

  public function launchRet(...values:Dynamic):Dynamic {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    syncFieldArgsToTensor(values);
    var result = Native.kernel_launch_ret(context.nativeHandle(), handle, nativeArgs(values));
    syncFieldArgsFromTensor(values);
    return result;
  }
  public function launchRets(...values:Dynamic):hl.NativeArray<Dynamic> {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    syncFieldArgsToTensor(values);
    var result = Native.kernel_launch_rets(context.nativeHandle(), handle, nativeArgs(values));
    syncFieldArgsFromTensor(values);
    return result;
  }



  public function launchOn(stream:Stream, ...values:Dynamic):Void {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    syncFieldArgsToTensor(values);
    Native.kernel_launch_on(context.nativeHandle(), handle, stream.nativeHandle(), nativeArgs(values));
    syncFieldArgsFromTensor(values);
  }

  public function launchGraph(...values:Dynamic):Void {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    syncFieldArgsToTensor(values);
    Native.kernel_launch_graph(context.nativeHandle(), handle, nativeArgs(values));
    syncFieldArgsFromTensor(values);
  }

  public function launchGraphDoWhile(controlArgId:Int, ...values:Dynamic):Void {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    syncFieldArgsToTensor(values);
    Native.kernel_launch_graph_do_while(context.nativeHandle(), handle, controlArgId, nativeArgs(values));
    syncFieldArgsFromTensor(values);
  }

  public function descriptorHash():String {
    var hash = 0x811c9dc5;
    for (i in 0...descriptorLength) {
      hash = (hash ^ descriptor.getUI8(i)) * 0x01000193;
    }
    return StringTools.hex(hash, 8);
  }
  public function grad():Kernel {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    return fromDescriptor(context, descriptor, descriptorLength, Reverse, graphLaunchByDefault);
  }

  public function forwardGrad():Kernel {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    return fromDescriptor(context, descriptor, descriptorLength, Forward, graphLaunchByDefault);
  }

  public function validationKernel():Kernel {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    return fromDescriptor(context, descriptor, descriptorLength, Validate, graphLaunchByDefault);
  }

  public function close():Void {
    if (!closed) {
      Native.kernel_close(handle);
      closed = true;
    }
  }
  #end
}
