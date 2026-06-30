package quadrants;

class Kernel {
  #if !macro
  final rawKernel:KernelRaw;

  @:noCompletion public function new(rawKernel:KernelRaw) {
    this.rawKernel = rawKernel;
  }

  public static function fromRaw(rawKernel:KernelRaw):Kernel {
    if (rawKernel == null) {
      throw "Quadrants kernel raw handle is required";
    }
    return new Kernel(rawKernel);
  }

  public static function fromDescriptor(context:Context,
      descriptor:hl.Bytes,
      ?descriptorLength:Int,
      autodiffMode:quadrants.Types.AutodiffMode = quadrants.Types.AutodiffMode.None,
      graphLaunchByDefault:Bool = false,
      kernelName:String = "haxe_kernel",
      reverseAutodiffBlockedReason:Null<String> = null):Kernel {
    return fromRaw(KernelRaw.fromDescriptor(context,
      descriptor,
      descriptorLength,
      autodiffMode,
      graphLaunchByDefault,
      kernelName,
      reverseAutodiffBlockedReason));
  }

  public function raw():KernelRaw {
    return rawKernel;
  }

  public function kernelName():String {
    return rawKernel.kernelName();
  }

  public function descriptorLengthBytes():Int {
    return rawKernel.descriptorLengthBytes();
  }

  public function descriptorByteAt(index:Int):Int {
    return rawKernel.descriptorByteAt(index);
  }

  public function autodiffModeValue():quadrants.Types.AutodiffMode {
    return rawKernel.autodiffModeValue();
  }

  public function graphLaunchByDefaultEnabled():Bool {
    return rawKernel.graphLaunchByDefaultEnabled();
  }

  public function reverseAutodiffReason():Null<String> {
    return rawKernel.reverseAutodiffReason();
  }

  public function isClosed():Bool {
    return rawKernel.isClosed();
  }
  #end

  public static macro function build(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.FlattenBuild.build(ctx, fn, options, false, "quadrants.Kernel.build");
  }

  @:noCompletion public static macro function buildRaw(ctx:haxe.macro.Expr, fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.buildRaw(ctx, fn, options);
  }

  public static macro function descriptorBytes(fn:haxe.macro.Expr, ?options:haxe.macro.Expr):haxe.macro.Expr {
    return quadrants.macro.KernelBuilder.descriptorBytes(fn, options);
  }

  #if !macro
  public function descriptorHash():String {
    return rawKernel.descriptorHash();
  }

  public function grad():Kernel {
    return fromRaw(rawKernel.grad());
  }

  public function forwardGrad():Kernel {
    return fromRaw(rawKernel.forwardGrad());
  }

  public function validationKernel():Kernel {
    return fromRaw(rawKernel.validationKernel());
  }

  public function close():Void {
    rawKernel.close();
  }
  #end
}
