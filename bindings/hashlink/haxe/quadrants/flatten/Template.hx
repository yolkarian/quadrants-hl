package quadrants.flatten;

import quadrants.FieldRuntime;
import quadrants.TensorHandle;
import quadrants.kernel.ArgEncoding;

class Template {
  public static function specKey(value:Dynamic):SpecKey {
    var key = new SpecKey();
    if (isScalarTemplateValue(value)) {
      key.addTemplate("root", value);
      return key;
    }
    if (Std.isOfType(value, TensorHandle) || Std.isOfType(value, FieldRuntime)) {
      key.addResource("root", ArgEncoding.specFragment(value));
      return key;
    }
    return Flattened.specKey(value);
  }

  static function isScalarTemplateValue(value:Dynamic):Bool {
    return switch (Type.typeof(value)) {
      case TNull | TInt | TFloat | TBool | TClass(String):
        true;
      default:
        false;
    };
  }
}
