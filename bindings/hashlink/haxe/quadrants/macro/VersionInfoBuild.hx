package quadrants.macro;

#if macro
import haxe.Json;
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
#end

class VersionInfoBuild {
  public static macro function packageVersion():ExprOf<String> {
    return macro $v{readPackageVersion()};
  }

  #if macro
  static function readPackageVersion():String {
    var versionInfoPath = Context.resolvePath("quadrants/VersionInfo.hx");
    var haxeRoot = Path.directory(Path.directory(versionInfoPath));
    var packageRoot = Path.directory(haxeRoot);
    var manifestPath = Path.join([packageRoot, "haxelib.json"]);
    if (!FileSystem.exists(manifestPath)) {
      Context.error('Quadrants haxelib manifest not found at ${manifestPath}', Context.currentPos());
    }
    Context.registerModuleDependency(Context.getLocalModule(), manifestPath);
    var manifest:Dynamic = Json.parse(File.getContent(manifestPath));
    var version:String = Reflect.field(manifest, "version");
    if (version == null || StringTools.trim(version).length == 0) {
      Context.error('Quadrants haxelib manifest is missing a version string', Context.currentPos());
    }
    return version;
  }
  #end
}
