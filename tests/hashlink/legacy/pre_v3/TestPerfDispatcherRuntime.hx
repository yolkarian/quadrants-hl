import quadrants.Types.Arch;
import quadrants.perf.PerfDispatchContext;
import quadrants.perf.PerfDispatcher;

private class DispatchGeometry {
  public final width:Int;
  public final height:Int;

  public function new(width:Int, height:Int) {
    this.width = width;
    this.height = height;
  }
}

class TestPerfDispatcherRuntime {
  static function geometryKey(geometry:DispatchGeometry):String {
    return geometry.width + "x" + geometry.height;
  }

  static function expectInt(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectString(name:String, got:String, expected:String):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectBool(name:String, got:Bool, expected:Bool):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function expectFalse(name:String, value:Bool):Void {
    if (value) throw '${name}: expected false';
  }

  static function testDeterministicSelection():Void {
    var context = new PerfDispatchContext(Arch.Cpu, "optA");
    var firstCalls = 0;
    var secondCalls = 0;
    var dispatcher = new PerfDispatcher<DispatchGeometry, String>(geometryKey, "deterministic-selection")
      .register("first", function(geometry:DispatchGeometry):Bool {
        return geometry.width > 0;
      }, function(_geometry:DispatchGeometry, context:PerfDispatchContext):String {
        firstCalls++;
        return "first:" + context.compileOptions;
      })
      .register("second", function(_geometry:DispatchGeometry):Bool {
        return true;
      }, function(_geometry:DispatchGeometry, _context:PerfDispatchContext):String {
        secondCalls++;
        return "second";
      });

    var first = dispatcher.select(new DispatchGeometry(4, 4), context);
    expectString("deterministic_candidate", first.candidateName, "first");
    expectString("deterministic_result", first.result, "first:optA");
    expectBool("deterministic_cache_miss", first.cacheHit, false);
    expectInt("deterministic_first_calls", firstCalls, 1);
    expectInt("deterministic_second_calls", secondCalls, 0);

    var second = dispatcher.select(new DispatchGeometry(0, 4), context);
    expectString("deterministic_fallback_candidate", second.candidateName, "second");
    expectString("deterministic_fallback_result", second.result, "second");
    expectBool("deterministic_fallback_cache_miss", second.cacheHit, false);
    expectInt("deterministic_first_calls_after_fallback", firstCalls, 1);
    expectInt("deterministic_second_calls_after_fallback", secondCalls, 1);
  }

  static function testStableCacheHitAndMiss():Void {
    var contextA = new PerfDispatchContext(Arch.Cpu, "tile=16");
    var contextB = new PerfDispatchContext(Arch.Cpu, "tile=32");
    var calls = 0;
    var dispatcher = new PerfDispatcher<DispatchGeometry, Int>(geometryKey, "stable-cache")
      .register("only", function(_geometry:DispatchGeometry):Bool {
        return true;
      }, function(_geometry:DispatchGeometry, _context:PerfDispatchContext):Int {
        calls++;
        return calls;
      });

    var geometry = new DispatchGeometry(8, 4);
    var equivalentGeometry = new DispatchGeometry(8, 4);
    var key = dispatcher.cacheKey(geometry, Arch.Cpu, "tile=16");
    expectString("stable_cache_key", dispatcher.cacheKey(equivalentGeometry, Arch.Cpu, "tile=16"), key);

    var first = dispatcher.select(geometry, contextA);
    expectBool("stable_cache_first_miss", first.cacheHit, false);
    expectInt("stable_cache_first_result", first.result, 1);
    expectTrue("stable_cache_has_key", dispatcher.hasCached(equivalentGeometry, contextA));
    expectString("stable_cache_name", dispatcher.cachedName(equivalentGeometry, contextA), "only");
    expectInt("stable_cache_size_after_first", dispatcher.cacheSize(), 1);

    var second = dispatcher.select(equivalentGeometry, contextA);
    expectBool("stable_cache_second_hit", second.cacheHit, true);
    expectInt("stable_cache_second_result", second.result, 1);
    expectInt("stable_cache_calls_after_hit", calls, 1);

    var third = dispatcher.select(geometry, contextB);
    expectBool("stable_cache_different_options_miss", third.cacheHit, false);
    expectInt("stable_cache_different_options_result", third.result, 2);
    expectInt("stable_cache_size_after_options_miss", dispatcher.cacheSize(), 2);

    expectTrue("stable_cache_clear_existing", dispatcher.clearCached(equivalentGeometry, contextA));
    expectFalse("stable_cache_cleared", dispatcher.hasCached(geometry, contextA));
    expectInt("stable_cache_size_after_clear", dispatcher.cacheSize(), 1);

    var fourth = dispatcher.select(geometry, contextA);
    expectBool("stable_cache_after_clear_miss", fourth.cacheHit, false);
    expectInt("stable_cache_after_clear_result", fourth.result, 3);
    expectInt("stable_cache_calls_after_clear", calls, 3);
  }

  static function testFailureDoesNotPoisonCache():Void {
    var context = new PerfDispatchContext(Arch.Cpu, "flaky");
    var attempts = 0;
    var dispatcher = new PerfDispatcher<DispatchGeometry, String>(geometryKey, "failure-cache")
      .register("flaky", function(_geometry:DispatchGeometry):Bool {
        return true;
      }, function(_geometry:DispatchGeometry, _context:PerfDispatchContext):String {
        attempts++;
        if (attempts == 1) {
          throw "compile failed";
        }
        return "compiled";
      });

    var geometry = new DispatchGeometry(16, 16);
    var failed = false;
    try {
      dispatcher.select(geometry, context);
    } catch (e:Dynamic) {
      failed = true;
    }
    expectTrue("failure_cache_first_attempt_failed", failed);
    expectInt("failure_cache_attempts_after_failure", attempts, 1);
    expectFalse("failure_cache_not_poisoned", dispatcher.hasCached(geometry, context));
    expectInt("failure_cache_size_after_failure", dispatcher.cacheSize(), 0);

    var success = dispatcher.select(geometry, context);
    expectBool("failure_cache_success_miss", success.cacheHit, false);
    expectString("failure_cache_success_candidate", success.candidateName, "flaky");
    expectString("failure_cache_success_result", success.result, "compiled");
    expectInt("failure_cache_attempts_after_success", attempts, 2);
    expectTrue("failure_cache_stored_after_success", dispatcher.hasCached(geometry, context));

    var hit = dispatcher.select(geometry, context);
    expectBool("failure_cache_hit", hit.cacheHit, true);
    expectString("failure_cache_hit_result", hit.result, "compiled");
    expectInt("failure_cache_attempts_after_hit", attempts, 2);
  }

  public static function run():Void {
    testDeterministicSelection();
    testStableCacheHitAndMiss();
    testFailureDoesNotPoisonCache();
  }

  static function main():Void {
    run();
    Sys.println("hashlink perf dispatcher ok");
  }
}
