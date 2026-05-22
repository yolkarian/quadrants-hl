import haxe.io.Path;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;
import sys.FileSystem;

class TestOfflineCacheRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function join(path:String, child:String):String {
    if (StringTools.endsWith(path, "/") || StringTools.endsWith(path, "\\")) {
      return path + child;
    }
    return path + (#if windows "\\" #else "/" #end) + child;
  }

  static function deleteTree(path:String):Void {
    if (!FileSystem.exists(path)) {
      return;
    }
    if (FileSystem.isDirectory(path)) {
      for (entry in FileSystem.readDirectory(path)) {
        deleteTree(join(path, entry));
      }
      FileSystem.deleteDirectory(path);
      return;
    }
    FileSystem.deleteFile(path);
  }

  static function metadataPath(cachePath:String):String {
    return join(join(cachePath, "kernel_compilation_manager"), "ticache.tcb");
  }

  static function runCachedKernel(arch:quadrants.Types.Arch, cachePath:String, value:Int):Int {
    var ctx:Context = null;
    var kernel:Kernel = null;
    try {
      ctx = new Context(arch);
      ctx.setOfflineCache(true, cachePath);
      expectTrue('offline_cache_enabled_state', ctx.offlineCacheEnabled);
      if (ctx.offlineCachePath != cachePath) throw 'offline_cache_path_state';
      var out = new Tensor<I32>(ctx, [1]);
      kernel = Kernel.build(ctx, macro (out:Tensor<I32>, value:Int) -> {
        out[0] = value * 2 + 1;
      });
      kernel.launch(out, value);
      ctx.sync();
      expectEq("offline_cache_value", out.read(0), value * 2 + 1);
    } catch (e:Dynamic) {
      TestRuntimeSupport.closeKernel(kernel);
      TestRuntimeSupport.closeContext(ctx);
      throw e;
    }
    TestRuntimeSupport.closeKernel(kernel);
    TestRuntimeSupport.closeContext(ctx);
    var metadata = metadataPath(cachePath);
    expectTrue("offline_cache_metadata_exists", FileSystem.exists(metadata));
    return Std.int(FileSystem.stat(metadata).size);
  }

  public static function run():Void {
    var requested = TestRuntimeSupport.requestedArchNames();
    if (requested.length > 0 && !TestRuntimeSupport.isRequested("cpu", requested)) {
      return;
    }
    var tempRoot = Sys.getEnv("TMPDIR");
    if (tempRoot == null || tempRoot.length == 0) {
      tempRoot = "/tmp";
    }
    var cacheRoot = join(tempRoot, 'quadrants-hashlink-offline-cache-cpu-${Date.now().getTime()}');
    FileSystem.createDirectory(cacheRoot);
    var firstCount = runCachedKernel(quadrants.Types.Arch.Cpu, cacheRoot, 7);
    expectTrue("offline_cache_created_files", firstCount > 0);
    var secondCount = runCachedKernel(quadrants.Types.Arch.Cpu, cacheRoot, 7);
    expectEq("offline_cache_reused_file_count", secondCount, firstCount);

    var clearCtx = new Context(quadrants.Types.Arch.Cpu);
    try {
      clearCtx.setOfflineCache(true, cacheRoot);
      clearCtx.clearOfflineCache();
      expectTrue('offline_cache_cleared', !FileSystem.exists(cacheRoot));
      clearCtx.close();
    } catch (e:Dynamic) {
      clearCtx.close();
      throw e;
    }
  }
}
