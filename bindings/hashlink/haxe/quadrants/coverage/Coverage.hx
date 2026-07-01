package quadrants.coverage;

import haxe.Json;
import quadrants.KernelRaw;
import quadrants.Types.AutodiffMode;
import sys.io.File;

typedef CoverageLaunchKind = {
  var kind:String;
  var count:Int;
}

typedef CoverageSnapshot = {
  var key:String;
  var kernelName:String;
  var descriptorHash:String;
  var descriptorLength:Int;
  var autodiffMode:String;
  var graphLaunchByDefault:Bool;
  var builds:Int;
  var launches:Int;
  var launchKinds:Array<CoverageLaunchKind>;
  var probeCount:Int;
  var coveredProbes:Int;
}

private class CoverageAccumulator {
  public final key:String;
  public final kernelName:String;
  public final descriptorHash:String;
  public final descriptorLength:Int;
  public final autodiffMode:String;
  public final graphLaunchByDefault:Bool;
  public final probeCount:Int;
  public var coveredProbes:Int = 0;
  public var builds:Int = 0;
  public var launches:Int = 0;
  final launchKinds:Map<String, Int> = new Map();

  public function new(key:String, kernel:KernelRaw) {
    this.key = key;
    kernelName = kernel.kernelName();
    descriptorHash = kernel.descriptorHash();
    descriptorLength = kernel.descriptorLengthBytes();
    autodiffMode = Coverage.autodiffModeName(kernel.autodiffModeValue());
    graphLaunchByDefault = kernel.graphLaunchByDefaultEnabled();
    probeCount = Coverage.sourceSpanProbeCount(kernel);
  }

  public function recordLaunch(kind:String):Void {
    launches++;
    var current = launchKinds.get(kind);
    launchKinds.set(kind, current == null ? 1 : current + 1);
    if (probeCount > coveredProbes) {
      coveredProbes = probeCount;
    }
  }

  public function snapshot():CoverageSnapshot {
    var kinds = new Array<CoverageLaunchKind>();
    for (kind in launchKinds.keys()) {
      kinds.push({kind: kind, count: launchKinds.get(kind)});
    }
    return {
      key: key,
      kernelName: kernelName,
      descriptorHash: descriptorHash,
      descriptorLength: descriptorLength,
      autodiffMode: autodiffMode,
      graphLaunchByDefault: graphLaunchByDefault,
      builds: builds,
      launches: launches,
      launchKinds: kinds,
      probeCount: probeCount,
      coveredProbes: coveredProbes
    };
  }
}

class Coverage {
  public static var enabled(default, null):Bool = false;
  static var records:Map<String, CoverageAccumulator> = new Map();
  static final order:Array<String> = [];

  public static function enable(resetFirst:Bool = false):Void {
    if (resetFirst) {
      reset();
    }
    enabled = true;
  }

  public static function disable():Void {
    enabled = false;
  }

  public static function reset():Void {
    records = new Map();
    order.resize(0);
  }

  public static function snapshot():Array<CoverageSnapshot> {
    var result:Array<CoverageSnapshot> = [];
    for (key in order) {
      var record = records.get(key);
      if (record != null) {
        result.push(record.snapshot());
      }
    }
    return result;
  }

  public static function flush(?path:String):String {
    var target = path == null ? "quadrants-coverage.json" : path;
    if (target.length == 0) {
      throw "Quadrants Coverage.flush requires a non-empty path";
    }
    File.saveContent(target, Json.stringify({
      version: 1,
      enabled: enabled,
      generatedAt: Date.now().toString(),
      kernels: snapshot()
    }));
    return target;
  }

  public static function registerKernelBuild(kernel:KernelRaw):Void {
    if (kernel == null) {
      throw "Quadrants Coverage cannot register a null kernel build";
    }
    if (!enabled) {
      return;
    }
    var record = recordFor(kernel);
    record.builds++;
  }

  public static function registerKernelLaunch(kernel:KernelRaw, kind:String):Void {
    if (kernel == null) {
      throw "Quadrants Coverage cannot register a null kernel launch";
    }
    if (kind == null || kind.length == 0) {
      throw "Quadrants Coverage launch kind must be non-empty";
    }
    if (!enabled) {
      return;
    }
    recordFor(kernel).recordLaunch(kind);
  }

  static function recordFor(kernel:KernelRaw):CoverageAccumulator {
    var key = kernelKey(kernel);
    var record = records.get(key);
    if (record == null) {
      record = new CoverageAccumulator(key, kernel);
      records.set(key, record);
      order.push(key);
    }
    return record;
  }

  static function kernelKey(kernel:KernelRaw):String {
    return kernel.kernelName() + ":" + kernel.descriptorHash() + ":" + autodiffModeName(kernel.autodiffModeValue()) + ":" + (kernel.graphLaunchByDefaultEnabled() ? "graph" : "direct");
  }

  public static function sourceSpanProbeCount(kernel:KernelRaw):Int {
    if (kernel == null) {
      throw "Quadrants Coverage cannot inspect a null kernel";
    }
    var length = kernel.descriptorLengthBytes();
    if (length < 20) {
      return 0;
    }
    var sectionCount = readU32(kernel, 8);
    var headerSize = readU32(kernel, 12);
    if (headerSize < 20 || headerSize + sectionCount * 12 > length) {
      return 0;
    }
    for (i in 0...sectionCount) {
      var entry = headerSize + i * 12;
      var kind = readU32(kernel, entry);
      if (kind == 2) {
        var offset = readU32(kernel, entry + 4);
        var sectionLength = readU32(kernel, entry + 8);
        if (offset < 0 || sectionLength < 4 || offset + sectionLength > length) {
          return 0;
        }
        return readU32(kernel, offset);
      }
    }
    return 0;
  }

  static function readU32(kernel:KernelRaw, offset:Int):Int {
    if (offset < 0 || offset + 4 > kernel.descriptorLengthBytes()) {
      return 0;
    }
    return kernel.descriptorByteAt(offset)
      | (kernel.descriptorByteAt(offset + 1) << 8)
      | (kernel.descriptorByteAt(offset + 2) << 16)
      | (kernel.descriptorByteAt(offset + 3) << 24);
  }

  public static function autodiffModeName(mode:AutodiffMode):String {
    return switch (mode) {
      case AutodiffMode.None: "none";
      case AutodiffMode.Forward: "forward";
      case AutodiffMode.Reverse: "reverse";
      case AutodiffMode.Validate: "validate";
    };
  }
}
