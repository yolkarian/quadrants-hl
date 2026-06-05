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

  public function new(context:Context, shape:Array<Int>, steps:Array<FieldPlacementStep>) {
    this.context = context;
    this.shape = [for (dim in shape) dim];
    this.rank = shape.length;
    this.steps = copySteps(steps);
  }

  public function placementSteps():Array<FieldPlacementStep> {
    return copySteps(steps);
  }

  public function place(field:FieldRuntime):FieldRuntime {
    FieldsBuilder.placeWithSteps(context, field, shape.copy(), copySteps(steps));
    return field;
  }

  public function placeMany(fields:Array<FieldRuntime>):Void {
    if (fields == null || fields.length == 0) {
      throw "Quadrants field placement path requires at least one field";
    }
    for (field in fields) {
      place(field);
    }
  }

  public function lazyGrad(field:Dynamic):Dynamic {
    return FieldTree.lazyGrad(field);
  }

  public function lazyDual(field:Dynamic):Dynamic {
    return FieldTree.lazyDual(field);
  }

  public function lazyFieldGrad<T>(field:Field<T>):Field<T> {
    return FieldTree.lazyFieldGrad(field);
  }

  public function lazyFieldDual<T>(field:Field<T>):Field<T> {
    return FieldTree.lazyFieldDual(field);
  }

  public function toString():String {
    return 'FieldPlacementPath(rank=${rank}, shape=[${shape.join(",")}])';
  }

  static function copySteps(input:Array<FieldPlacementStep>):Array<FieldPlacementStep> {
    return [for (step in input) {kind: step.kind, axis: step.axis, size: step.size, chunkSize: step.chunkSize}];
  }
}
