package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

class QKernelTypeBuilder {
  static final ensured:Map<Int, Bool> = new Map();

  public static function ensure(arity:Int, pos:Position):Void {
    if (arity < 0) {
      Context.error("Quadrants typed kernel arity cannot be negative", pos);
    }
    if (ensured.exists(arity)) {
      return;
    }

    var name = className(arity);
    try {
      Context.getType("quadrants.kernel." + name);
      ensured.set(arity, true);
      return;
    } catch (_:Dynamic) {}

    Context.defineType({
      pack: ["quadrants", "kernel"],
      name: name,
      pos: pos,
      meta: [],
      params: typeParameters(arity),
      isExtern: false,
      kind: TDClass(null, [{pack: ["quadrants", "kernel"], name: "QKernel", params: []}], false, false, false),
      fields: fields(arity, pos),
    });
    ensured.set(arity, true);
  }

  static function fields(arity:Int, pos:Position):Array<Field> {
    var result = new Array<Field>();
    var argumentTypes = [for (index in 0...arity) typeParameter(argumentName(index))];
    var resultType = typeParameter("R");
    var selfType = kernelType(arity);
    var launchType = functionType(argumentTypes, resultType);
    var launchOnType = functionType([streamType()].concat(argumentTypes), resultType);
    var wrapType = functionType([rawKernelType()], selfType);
    var argumentNames = [for (index in 0...arity) 'a${index}'];
    var argumentList = argumentNames.join(", ");
    var streamArgumentList = arity == 0 ? "stream" : "stream, " + argumentList;
    var valueArray = "[" + argumentList + "]";

    function add(name:String, access:Array<Access>, kind:FieldType):Void {
      result.push({name: name, access: access, kind: kind, pos: pos, meta: []});
    }

    function functionField(args:Array<FunctionArg>, ret:Null<ComplexType>, body:String):FieldType {
      return FFun({args: args, ret: ret, expr: Context.parse(body, pos), params: []});
    }

    function launchArguments():Array<FunctionArg> {
      return [for (index in 0...arity) argument('a${index}', argumentTypes[index])];
    }

    function controlArguments():Array<FunctionArg> {
      var args = [argument("control", graphControlType())];
      for (index in 0...arity) {
        args.push(argument('a${index}', argumentTypes[index]));
      }
      return args;
    }

    function tapeArguments(includeStream:Bool):Array<FunctionArg> {
      var args = new Array<FunctionArg>();
      if (includeStream) {
        args.push(argument("stream", streamType()));
      }
      args.push(argument("tape", tapeType()));
      for (index in 0...arity) {
        args.push(argument('a${index}', argumentTypes[index]));
      }
      return args;
    }

    add("rawKernel", [AFinal], FVar(rawKernelType(), null));
    add("launchFn", [AFinal], FVar(launchType, null));
    add("launchOnFn", [AFinal], FVar(launchOnType, null));
    add("launchGraphFn", [AFinal], FVar(launchType, null));
    add("wrapRaw", [AFinal], FVar(wrapType, null));

    add("new", [APublic], functionField([
      argument("rawKernel", rawKernelType()),
      argument("launchFn", launchType),
      argument("launchOnFn", launchOnType),
      argument("launchGraphFn", launchType),
      argument("wrapRaw", wrapType),
    ], null, "{ this.rawKernel = rawKernel; this.launchFn = launchFn; this.launchOnFn = launchOnFn; this.launchGraphFn = launchGraphFn; this.wrapRaw = wrapRaw; }"));

    add("raw", [APublic], functionField([], rawKernelType(), "{ return rawKernel; }"));
    add("name", [APublic], functionField([], stringType(), "{ return rawKernel.kernelName(); }"));
    add("launch", [APublic], functionField(launchArguments(), resultType, '{ return launchFn(${argumentList}); }'));
    add("launchOn", [APublic], functionField([argument("stream", streamType())].concat(launchArguments()), resultType, '{ return launchOnFn(${streamArgumentList}); }'));
    add("launchGraph", [APublic], functionField(launchArguments(), resultType, '{ return launchGraphFn(${argumentList}); }'));
    add("grad", [APublic], functionField([], selfType, "{ return wrapRaw(rawKernel.grad()); }"));
    add("forwardGrad", [APublic], functionField([], selfType, "{ return wrapRaw(rawKernel.forwardGrad()); }"));
    add("validationKernel", [APublic], functionField([], selfType, "{ return wrapRaw(rawKernel.validationKernel()); }"));
    add("launchGraphWhile", [APublic], functionField(controlArguments(), resultType, '{ while (control.read(0) != 0) { launchGraph(${argumentList}); control.context.sync(); } return cast null; }'));

    var doWhileBody = arity == 0
      ? "{ return QKernelGraph.launchGraphDoWhile(rawKernel, control, []); }"
      : '{ var values:Array<Dynamic> = ${valueArray}; return QKernelGraph.launchGraphDoWhile(rawKernel, control, values); }';
    add("launchGraphDoWhile", [APublic], functionField(controlArguments(), resultType, doWhileBody));
    add("launchTape", [APublic], functionField(tapeArguments(false), resultType, '{ tape.recordKernel(this, ${valueArray}); return launch(${argumentList}); }'));
    add("launchTapeOn", [APublic], functionField(tapeArguments(true), resultType, '{ throw "Quadrants Tape launch on explicit streams is not supported; launch typed tape kernels on the default stream and use stream kernels outside Tape"; }'));
    add("descriptorHash", [APublic], functionField([], stringType(), "{ return rawKernel.descriptorHash(); }"));
    add("descriptorLengthBytes", [APublic], functionField([], intType(), "{ return rawKernel.descriptorLengthBytes(); }"));
    add("descriptorByteAt", [APublic], functionField([argument("index", intType())], intType(), "{ return rawKernel.descriptorByteAt(index); }"));
    add("descriptor", [APublic], functionField([], descriptorMetadataType(), "{ return quadrants.descriptor.Descriptor.fromKernel(this); }"));
    add("close", [APublic], functionField([], voidType(), "{ rawKernel.close(); }"));

    return result;
  }

  static function className(arity:Int):String {
    return 'QKernel${arity}';
  }

  static function typeParameters(arity:Int):Array<TypeParamDecl> {
    var params = [for (index in 0...arity) ({name: argumentName(index)} : TypeParamDecl)];
    params.push({name: "R"});
    return params;
  }

  static function argumentName(index:Int):String {
    return 'A${index}';
  }

  static function kernelType(arity:Int):ComplexType {
    return TPath({
      pack: ["quadrants", "kernel"],
      name: className(arity),
      params: [for (index in 0...arity) TPType(typeParameter(argumentName(index)))].concat([TPType(typeParameter("R"))]),
    });
  }

  static function functionType(args:Array<ComplexType>, ret:ComplexType):ComplexType {
    return TFunction(args, ret);
  }

  static function argument(name:String, type:ComplexType):FunctionArg {
    return {name: name, opt: false, type: type, value: null};
  }

  static function typeParameter(name:String):ComplexType {
    return TPath({pack: [], name: name, params: []});
  }

  static function rawKernelType():ComplexType return macro : quadrants.KernelRaw;
  static function streamType():ComplexType return macro : quadrants.Stream;
  static function tapeType():ComplexType return macro : quadrants.Tape;
  static function graphControlType():ComplexType return macro : quadrants.Tensor<quadrants.Types.I32>;
  static function descriptorMetadataType():ComplexType return macro : quadrants.descriptor.Descriptor.QdhlDescriptorMetadata;
  static function stringType():ComplexType return macro : String;
  static function intType():ComplexType return macro : Int;
  static function voidType():ComplexType return macro : Void;
}
#end
