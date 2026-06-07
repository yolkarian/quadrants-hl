package quadrants.perf;

import quadrants.Types.Arch;

private class PerfDispatchCandidate<TGeometry, TResult> {
  public final name:String;
  public final predicate:TGeometry->Bool;
  public final candidate:(TGeometry, PerfDispatchContext)->TResult;

  public function new(name:String, predicate:TGeometry->Bool, candidate:(TGeometry, PerfDispatchContext)->TResult) {
    this.name = name;
    this.predicate = predicate;
    this.candidate = candidate;
  }
}

private class PerfDispatchCacheEntry<TResult> {
  public final candidateName:String;
  public final result:TResult;

  public function new(candidateName:String, result:TResult) {
    this.candidateName = candidateName;
    this.result = result;
  }
}

class PerfDispatcher<TGeometry, TResult> {
  public final namespace:String;

  final geometryKey:TGeometry->String;
  final candidates:Array<PerfDispatchCandidate<TGeometry, TResult>> = [];
  final candidateNames:Map<String, Bool> = new Map();
  final cache:Map<String, PerfDispatchCacheEntry<TResult>> = new Map();

  public function new(geometryKey:TGeometry->String, namespace:String = "default") {
    if (geometryKey == null) {
      throw "Quadrants PerfDispatcher geometry key function is required";
    }
    if (namespace == null || namespace.length == 0) {
      throw "Quadrants PerfDispatcher namespace must be non-empty";
    }
    this.geometryKey = geometryKey;
    this.namespace = namespace;
  }

  public function register(name:String, geometryPredicate:TGeometry->Bool, candidate:(TGeometry, PerfDispatchContext)->TResult):PerfDispatcher<TGeometry, TResult> {
    if (name == null || name.length == 0) {
      throw "Quadrants PerfDispatcher candidate name must be non-empty";
    }
    if (candidateNames.exists(name)) {
      throw 'Quadrants PerfDispatcher candidate ${name} is already registered';
    }
    if (geometryPredicate == null) {
      throw 'Quadrants PerfDispatcher candidate ${name} predicate is required';
    }
    if (candidate == null) {
      throw 'Quadrants PerfDispatcher candidate ${name} function is required';
    }
    candidates.push(new PerfDispatchCandidate(name, geometryPredicate, candidate));
    candidateNames.set(name, true);
    return this;
  }

  public function select(geometry:TGeometry, context:PerfDispatchContext):PerfDispatchSelection<TGeometry, TResult> {
    requireContext(context);
    var key = cacheKey(geometry, context.arch, context.compileOptions);
    var cached = cache.get(key);
    if (cached != null) {
      return new PerfDispatchSelection(key, cached.candidateName, cached.result, true);
    }

    for (entry in candidates) {
      if (entry.predicate(geometry)) {
        var result = entry.candidate(geometry, context);
        cache.set(key, new PerfDispatchCacheEntry(entry.name, result));
        return new PerfDispatchSelection(key, entry.name, result, false);
      }
    }

    throw 'Quadrants PerfDispatcher found no candidate for cache key ${key}';
  }

  public function selectValue(geometry:TGeometry, context:PerfDispatchContext):TResult {
    return select(geometry, context).result;
  }


  public function cacheKey(geometry:TGeometry, arch:Arch, compileOptions:String = ""):String {
    var geometryPart = geometryKey(geometry);
    if (geometryPart == null || geometryPart.length == 0) {
      throw "Quadrants PerfDispatcher geometry cache key must be non-empty";
    }
    var options = compileOptions == null ? "" : compileOptions;
    return "quadrants-perf|" + lengthPrefixed(namespace) + "|" + archName(arch) + "|" + lengthPrefixed(options) + "|" + lengthPrefixed(geometryPart);
  }

  public function cacheKeyForContext(geometry:TGeometry, context:PerfDispatchContext):String {
    requireContext(context);
    return cacheKey(geometry, context.arch, context.compileOptions);
  }

  public function hasCached(geometry:TGeometry, context:PerfDispatchContext):Bool {
    return cache.exists(cacheKeyForContext(geometry, context));
  }

  public function cachedName(geometry:TGeometry, context:PerfDispatchContext):Null<String> {
    var entry = cache.get(cacheKeyForContext(geometry, context));
    return entry == null ? null : entry.candidateName;
  }

  public function clearCached(geometry:TGeometry, context:PerfDispatchContext):Bool {
    return cache.remove(cacheKeyForContext(geometry, context));
  }

  public function clearCache():Void {
    cache.clear();
  }

  public function cacheSize():Int {
    var count = 0;
    for (_ in cache.keys()) {
      count++;
    }
    return count;
  }

  public function candidateCount():Int {
    return candidates.length;
  }

  static function lengthPrefixed(value:String):String {
    return Std.string(value.length) + ":" + value;
  }

  static function requireContext(context:PerfDispatchContext):Void {
    if (context == null) {
      throw "Quadrants PerfDispatcher selection context is required";
    }
  }

  static function archName(arch:Arch):String {
    return switch (arch) {
      case Arch.Cpu: "cpu";
      case Arch.Cuda: "cuda";
      case Arch.Vulkan: "vulkan";
      case Arch.Metal: "metal";
      case Arch.Amdgpu: "amdgpu";
    };
  }
}
