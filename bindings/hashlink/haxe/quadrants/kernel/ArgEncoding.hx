package quadrants.kernel;

import quadrants.BufferView;
import quadrants.FieldRuntime;
import quadrants.TensorHandle;

class ArgEncoding {
  public static function append<T>(buf:ArgBuffer, value:T):Void {
    buf.addValue(value);
  }

  public static function specFragment(value:Dynamic):String {
    if (value == null) {
      return "null";
    }
    if (Std.isOfType(value, TensorHandle)) {
      var tensor:TensorHandle = cast value;
      return 'tensor:${tensor.dtype}:${tensor.shape.join("x")}';
    }
    if (Std.isOfType(value, FieldRuntime)) {
      var field:FieldRuntime = cast value;
      var shape = field.shape == null ? "unplaced" : field.shape.join("x");
      return 'field:${field.dtype}:${shape}:${field.snodeId}';
    }
    if (Std.isOfType(value, BufferView)) {
      var view:BufferView<Dynamic> = cast value;
      return 'view:${specFragment(view.tensor)}:${view.flatStart}:${view.length}';
    }
    return Std.string(value);
  }
}
