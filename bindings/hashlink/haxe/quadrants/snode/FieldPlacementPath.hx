package quadrants.snode;

import quadrants.Context;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.FieldsBuilder;
import quadrants.FieldsBuilder.FieldPlacementStep;

class FieldPlacementPath {
  public final context:Context;
  public final shape:Array<Int>;
  public final rank:Int;
  final steps:Array<FieldPlacementStep>;
  final offset:Array<Int>;

  public function new(context:Context, shape:Array<Int>, steps:Array<FieldPlacementStep>, ?offset:Array<Int>) {
    this.context = context;
    this.shape = [for (dim in shape) dim];
    this.rank = shape.length;
    this.steps = copySteps(steps);
    this.offset = FieldsBuilder.validatePlacementOffset(this.shape, offset);
  }

  public function placementSteps():Array<FieldPlacementStep> {
    return copySteps(steps);
  }

  public function placementOffset():Array<Int> {
    return copyOffset(offset);
  }

  public function place(field:FieldRuntime):FieldRuntime {
    FieldsBuilder.placeWithSteps(context, field, shape.copy(), copySteps(steps), copyOffset(offset));
    return field;
  }

  public function placeField<T>(field:Field<T>):Field<T> {
    place(cast field);
    return field;
  }

  public function placeQuant<T>(field:Field<T>, spec:quadrants.quant.QuantStorageSpec<T>):Field<T> {
    FieldsBuilder.placeQuantWithSteps(context, field, shape.copy(), copySteps(steps), spec, copyOffset(offset));
    return field;
  }

  public function placeFields<T>(fields:Array<Field<T>>):Void {
    if (fields == null || fields.length == 0) {
      throw "Quadrants typed field placement path requires at least one field";
    }
    for (field in fields) {
      placeField(field);
    }
  }

  public function lazyFieldGrad<T>(field:Field<T>):Field<T> {
    return FieldTree.lazyFieldGrad(field);
  }

  public function lazyFieldDual<T>(field:Field<T>):Field<T> {
    return FieldTree.lazyFieldDual(field);
  }

  public function toString():String {
    return 'FieldPlacementPath(rank=${rank}, shape=[${shape.join(",")}], offset=[${offset.join(",")}])';
  }

  static function copyOffset(input:Array<Int>):Array<Int> {
    return [for (value in input) value];
  }

  static function copySteps(input:Array<FieldPlacementStep>):Array<FieldPlacementStep> {
    return [for (step in input) {kind: step.kind, axis: step.axis, size: step.size, chunkSize: step.chunkSize}];
  }
}
