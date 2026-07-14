package quadrants;

typedef KernelOptions = {
  @:optional var name:String;
  @:optional var debugName:String;
  @:optional var graph:Bool;
  @:optional var autodiff:quadrants.Types.AutodiffMode;
  @:optional var helpers:Array<Class<Dynamic>>;
  @:optional var boundaryClamp:Array<String>;
  @:optional var __qdhlMeta:Dynamic;
}
