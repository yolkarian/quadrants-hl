package quadrants;

class StructTensor<S> {
  public final context:Context;
  public final shape:Array<Int>;
  public final layout:LayoutPolicy;

  function new(context:Context, shape:Array<Int>, layout:LayoutPolicy) {
    this.context = context;
    this.shape = shape == null ? [] : shape.copy();
    this.layout = layout;
  }

  public static function alloc<S>(context:Context, shape:Array<Int>, layout:LayoutPolicy = LayoutPolicy.AOS):StructTensor<S> {
    throw "Quadrants StructTensor<S> storage is scheduled for Phase 5; QdStruct metadata is required before allocation";
  }
}
