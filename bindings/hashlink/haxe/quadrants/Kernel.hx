package quadrants;

#if !macro
import quadrants.Native.QKernel;
#end

class Kernel {
  #if !macro
  final context:Context;
  final handle:QKernel;
  var closed:Bool = false;

  function new(context:Context, handle:QKernel) {
    this.context = context;
    this.handle = handle;
  }

  public static function fromDescriptor(context:Context, descriptor:hl.Bytes, ?descriptorLength:Int):Kernel {
    if (descriptorLength == null) {
      throw "Quadrants descriptor length is required for raw hl.Bytes descriptors";
    }
    return new Kernel(context, Native.kernel_compile(context.nativeHandle(), descriptor, descriptorLength));
  }
  #end

  public static macro function build(ctx:haxe.macro.Expr, fn:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.build(ctx, fn);
  }

  #if !macro
  public function launch(...values:Dynamic):Void {
    if (closed) {
      throw "Quadrants kernel is closed";
    }
    var nativeArgs = new hl.NativeArray<Dynamic>(values.length);
    for (i in 0...values.length) {
      var value:Dynamic = values[i];
      if (Std.isOfType(value, Tensor)) {
        var tensor:Tensor<Dynamic> = cast value;
        nativeArgs[i] = tensor.nativeHandle();
      } else {
        nativeArgs[i] = value;
      }
    }
    Native.kernel_launch(context.nativeHandle(), handle, nativeArgs);
  }

  public function close():Void {
    if (!closed) {
      Native.kernel_close(handle);
      closed = true;
    }
  }
  #end
}
