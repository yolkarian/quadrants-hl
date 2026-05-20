package quadrants.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

class NativeLibrary {
  static inline final DEFAULT_LIBRARY = "quadrants";

  public static macro function build():Array<Field> {
    var fields = Context.getBuildFields();
    var library = resolveNativeLibrary();
    if (library == DEFAULT_LIBRARY) {
      return fields;
    }

    for (field in fields) {
      if (field.meta == null) {
        continue;
      }
      for (meta in field.meta) {
        if ((meta.name == ":hlNative" || meta.name == "hlNative") && meta.params != null && meta.params.length > 0) {
          meta.params[0] = macro $v{library};
        }
      }
    }
    return fields;
  }

  public static macro function runtimeLibDir():ExprOf<String> {
    return macro $v{resolveRuntimeLibDir()};
  }

  #if macro
  static function resolveNativeLibrary():String {
    var explicit = firstNonEmpty([
      Context.definedValue("quadrants_hdll_path"),
      Sys.getEnv("QUADRANTS_HDLL"),
    ]);
    if (explicit != null) {
      return libraryBase(explicit);
    }

    for (candidate in nativeLibraryCandidates()) {
      if (FileSystem.exists(candidate)) {
        return libraryBaseForExistingHdll(candidate);
      }
    }
    return DEFAULT_LIBRARY;
  }

  static function resolveRuntimeLibDir():String {
    var explicit = firstNonEmpty([
      Context.definedValue("quadrants_runtime_dir"),
      Sys.getEnv("QUADRANTS_RUNTIME_DIR"),
      Sys.getEnv("QD_LIB_DIR"),
    ]);
    if (explicit != null) {
      return absolutePath(explicit);
    }

    for (candidate in runtimeDirCandidates()) {
      if (isRuntimeDir(candidate)) {
        return fullPath(candidate);
      }
    }
    return "";
  }

  static function nativeLibraryCandidates():Array<String> {
    var roots = packageRoots();
    var result:Array<String> = [];
    for (root in roots) {
      result.push(join(root, "quadrants.hdll"));
      result.push(join(root, "quadrants64.hdll"));
      result.push(join(root, "hdll/quadrants.hdll"));
      result.push(join(root, "hdll/quadrants64.hdll"));
    }
    return result;
  }

  static function runtimeDirCandidates():Array<String> {
    var roots = packageRoots();
    var result:Array<String> = [];
    for (root in roots) {
      result.push(join(root, "runtime"));
      result.push(join(root, "../runtime"));
    }
    return result;
  }

  static function packageRoots():Array<String> {
    var roots:Array<String> = [];
    try {
      var nativeHx = Context.resolvePath("quadrants/Native.hx");
      addPackageRoots(roots, parent(parent(nativeHx)));
    } catch (_:Dynamic) {
    }
    for (classPath in Context.getClassPath()) {
      if (classPath != null && classPath.length > 0 && FileSystem.exists(join(classPath, "quadrants/Native.hx"))) {
        addPackageRoots(roots, classPath);
      }
    }
    return uniqueAbsolutePaths(roots);
  }

  static function addPackageRoots(roots:Array<String>, sourceRoot:String):Void {
    var absoluteSourceRoot = fullPath(sourceRoot);
    var haxelibRoot = parent(absoluteSourceRoot);
    if (FileSystem.exists(join(haxelibRoot, "haxelib.json"))) {
      roots.push(haxelibRoot);
    }
    roots.push(absoluteSourceRoot);
  }

  static function isRuntimeDir(path:String):Bool {
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) {
      return false;
    }
    try {
      for (entry in FileSystem.readDirectory(path)) {
        if (StringTools.endsWith(entry, ".bc")) {
          return true;
        }
      }
    } catch (_:Dynamic) {
    }
    return false;
  }

  static function firstNonEmpty(values:Array<Null<String>>):Null<String> {
    for (value in values) {
      if (value == null) {
        continue;
      }
      var trimmed = StringTools.trim(value);
      if (trimmed.length > 0) {
        return trimmed;
      }
    }
    return null;
  }

  static function libraryBase(path:String):String {
    if (!hasPathSeparator(path)) {
      return stripHdllExtension(path);
    }
    return stripHdllExtension(absolutePath(path));
  }

  static function libraryBaseForExistingHdll(path:String):String {
    var normalizedPath = fullPath(path);
    var directory = parent(normalizedPath);
    var basename = fileName(normalizedPath);
    if (basename == "quadrants64.hdll") {
      return absolutePath(join(directory, "quadrants"));
    }
    return stripHdllExtension(normalizedPath);
  }

  static function stripHdllExtension(path:String):String {
    return StringTools.endsWith(path, ".hdll") ? path.substr(0, path.length - 5) : path;
  }

  static function hasPathSeparator(path:String):Bool {
    return path.indexOf("/") >= 0 || path.indexOf("\\") >= 0;
  }

  static function uniqueAbsolutePaths(paths:Array<String>):Array<String> {
    var result:Array<String> = [];
    var seen = new Map<String, Bool>();
    for (path in paths) {
      var absolute = absolutePath(path);
      if (!seen.exists(absolute)) {
        seen[absolute] = true;
        result.push(absolute);
      }
    }
    return result;
  }

  static function absolutePath(path:String):String {
    return FileSystem.absolutePath(path);
  }

  static function fullPath(path:String):String {
    try {
      return FileSystem.fullPath(path);
    } catch (_:Dynamic) {
      return absolutePath(path);
    }
  }

  static function parent(path:String):String {
    var normalized = normalizeSeparators(path);
    var index = normalized.lastIndexOf("/");
    if (index < 0) {
      return ".";
    }
    if (index == 0) {
      return "/";
    }
    return normalized.substr(0, index);
  }

  static function fileName(path:String):String {
    var normalized = normalizeSeparators(path);
    var index = normalized.lastIndexOf("/");
    return index < 0 ? normalized : normalized.substr(index + 1);
  }

  static function join(base:String, relative:String):String {
    if (base == "" || base == ".") {
      return relative;
    }
    return StringTools.endsWith(base, "/") || StringTools.endsWith(base, "\\") ? base + relative : base + "/" + relative;
  }

  static function normalizeSeparators(path:String):String {
    return StringTools.replace(path, "\\", "/");
  }
  #end
}
