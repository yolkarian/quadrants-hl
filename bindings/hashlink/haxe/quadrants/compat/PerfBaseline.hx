package quadrants.compat;

typedef PerfSample = {
  var label:String;
  var iterations:Int;
  var seconds:Float;
  var secondsPerIteration:Float;
}

class PerfBaseline {
  public static function measure(label:String, iterations:Int, body:Void->Void):PerfSample {
    if (label == null || label.length == 0) {
      throw "Quadrants PerfBaseline label must be non-empty";
    }
    if (iterations <= 0) {
      throw "Quadrants PerfBaseline iterations must be positive";
    }
    if (body == null) {
      throw "Quadrants PerfBaseline body is required";
    }
    var start = haxe.Timer.stamp();
    for (_ in 0...iterations) {
      body();
    }
    var seconds = haxe.Timer.stamp() - start;
    if (seconds < 0) {
      seconds = 0;
    }
    return {
      label: label,
      iterations: iterations,
      seconds: seconds,
      secondsPerIteration: seconds / iterations
    };
  }
}
