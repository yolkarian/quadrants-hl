package quadrants.flatten;

import haxe.rtti.Meta;
import quadrants.FieldRuntime;
import quadrants.TensorHandle;
import quadrants.kernel.ArgEncoding;

class Flattened {
  public static function specKey(value:Dynamic):SpecKey {
    var key = new SpecKey();
    append(key, value, "root");
    return key;
  }

  static function append(key:SpecKey, value:Dynamic, path:String):Void {
    if (value == null) {
      return;
    }
    if (Std.isOfType(value, TensorHandle) || Std.isOfType(value, FieldRuntime)) {
      key.addResource(path, ArgEncoding.specFragment(value));
      return;
    }

    var cls = Type.getClass(value);
    if (cls == null) {
      return;
    }
    var typeMeta = Meta.getType(cls);
    var fieldMeta = Meta.getFields(cls);
    var flattenMeta = Reflect.hasField(typeMeta, "qdFlatten") || Reflect.hasField(typeMeta, ":qdFlatten")
      || Reflect.hasField(typeMeta, "qdDataOriented") || Reflect.hasField(typeMeta, ":qdDataOriented");
    if (!flattenMeta) {
      return;
    }

    for (field in Reflect.fields(value)) {
      var meta:Dynamic = Reflect.field(fieldMeta, field);
      if (hasMeta(meta, "qdIgnore") || hasMeta(meta, ":qdIgnore")) {
        continue;
      }
      var fieldValue = Reflect.field(value, field);
      var nextPath = path + "." + field;
      if (hasMeta(meta, "template") || hasMeta(meta, ":template")) {
        key.addTemplate(nextPath, fieldValue);
      } else if (Std.isOfType(fieldValue, TensorHandle) || Std.isOfType(fieldValue, FieldRuntime)) {
        key.addResource(nextPath, ArgEncoding.specFragment(fieldValue));
      } else {
        append(key, fieldValue, nextPath);
      }
    }
  }

  static function hasMeta(meta:Dynamic, name:String):Bool {
    return meta != null && Reflect.hasField(meta, name);
  }
}
