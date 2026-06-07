package quadrants.flatten;

import haxe.rtti.Rtti;
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
    if (!Rtti.hasRtti(cls)) {
      return;
    }
    var info = Rtti.getRtti(cls);
    if (!hasRttiMeta(info.meta, ":qdFlatten") && !hasRttiMeta(info.meta, ":qdDataOriented")) {
      return;
    }

    var fieldInfos = new Map<String, haxe.rtti.CType.ClassField>();
    for (fieldInfo in info.fields) {
      fieldInfos.set(fieldInfo.name, fieldInfo);
    }

    for (field in Reflect.fields(value)) {
      var fieldInfo = fieldInfos.get(field);
      if (fieldInfo != null && hasRttiMeta(fieldInfo.meta, ":qdIgnore")) {
        continue;
      }
      var fieldValue = Reflect.field(value, field);
      var nextPath = path + "." + field;
      if (fieldInfo != null && hasRttiMeta(fieldInfo.meta, ":template")) {
        key.addTemplate(nextPath, fieldValue);
      } else if (Std.isOfType(fieldValue, TensorHandle) || Std.isOfType(fieldValue, FieldRuntime)) {
        key.addResource(nextPath, ArgEncoding.specFragment(fieldValue));
      } else {
        append(key, fieldValue, nextPath);
      }
    }
  }

  static function hasRttiMeta(meta:Array<{name:String, params:Array<String>}>, name:String):Bool {
    if (meta == null) {
      return false;
    }
    for (entry in meta) {
      if (entry.name == name) {
        return true;
      }
    }
    return false;
  }
}
