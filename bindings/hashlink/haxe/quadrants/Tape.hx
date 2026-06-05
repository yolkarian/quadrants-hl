package quadrants;

import quadrants.ad.CustomGradient;

private class TapeRecord {
  final kernel:Kernel;
  final custom:Null<CustomGradient>;
  public final args:Array<Dynamic>;

  public function new(kernel:Kernel, args:Array<Dynamic>, ?custom:CustomGradient) {
    if (kernel == null) {
      throw "Quadrants tape cannot record a null kernel";
    }
    this.kernel = kernel;
    this.custom = custom;
    this.args = [for (arg in args) arg];
  }

  public static function fromKernel(kernel:Kernel, args:Array<Dynamic>):TapeRecord {
    return new TapeRecord(kernel, args);
  }

  public static function fromCustom(custom:CustomGradient, args:Array<Dynamic>):TapeRecord {
    if (custom == null) {
      throw "Quadrants tape cannot record a null custom gradient";
    }
    return new TapeRecord(custom.forward, args, custom);
  }

  public function launchBackward():Void {
    if (custom != null) {
      launchBorrowed(custom.backward);
      return;
    }
    launchDerived(kernel.grad());
  }

  public function launchForward():Void {
    if (custom != null && custom.forwardGrad != null) {
      launchBorrowed(custom.forwardGrad);
      return;
    }
    launchDerived(kernel.forwardGrad());
  }

  public function launchValidate():Void {
    if (custom != null && custom.validate != null) {
      launchBorrowed(custom.validate);
      return;
    }
    launchDerived(kernel.validationKernel());
  }

  function launchBorrowed(replayKernel:Kernel):Void {
    replayKernel.launch(...args);
  }

  function launchDerived(replayKernel:Kernel):Void {
    try {
      replayKernel.launch(...args);
    } catch (e:Dynamic) {
      replayKernel.close();
      throw e;
    }
    replayKernel.close();
  }
}

class Tape {
  final records:Array<TapeRecord> = [];
  public var recording(default, null):Bool = true;

  public function new() {}

  public static function run(body:Tape->Void):Tape {
    if (body == null) {
      throw "Quadrants Tape.run requires a body callback";
    }
    var tape = new Tape();
    body(tape);
    return tape;
  }

  public static function runBackward(body:Tape->Void, clearAfter:Bool = false):Tape {
    var tape = run(body);
    tape.backward(clearAfter);
    return tape;
  }

  public static function runForward(body:Tape->Void, clearAfter:Bool = false):Tape {
    var tape = run(body);
    tape.forward(clearAfter);
    return tape;
  }

  public static function runValidate(body:Tape->Void, clearAfter:Bool = false):Tape {
    var tape = run(body);
    tape.validate(clearAfter);
    return tape;
  }

  public var length(get, never):Int;
  function get_length():Int return records.length;

  public function pause():Void {
    recording = false;
  }

  public function resume():Void {
    recording = true;
  }

  public function clear():Void {
    records.resize(0);
  }

  public function record(kernel:Kernel, args:Array<Dynamic>):Void {
    if (recording) {
      records.push(TapeRecord.fromKernel(kernel, args));
    }
  }

  public function recordCustom(custom:CustomGradient, args:Array<Dynamic>):Void {
    if (recording) {
      records.push(TapeRecord.fromCustom(custom, args));
    }
  }

  public function launch(kernel:Kernel, ...args:Dynamic):Void {
    kernel.launch(...args);
    record(kernel, args);
  }

  public function launchCustom(custom:CustomGradient, ...args:Dynamic):Void {
    if (custom == null) {
      throw "Quadrants tape cannot launch a null custom gradient";
    }
    custom.forward.launch(...args);
    recordCustom(custom, args);
  }

  public function backward(clearAfter:Bool = false):Void {
    var i = records.length;
    while (i > 0) {
      i--;
      records[i].launchBackward();
    }
    if (clearAfter) {
      clear();
    }
  }

  public function forward(clearAfter:Bool = false):Void {
    for (record in records) {
      record.launchForward();
    }
    if (clearAfter) {
      clear();
    }
  }

  public function validate(clearAfter:Bool = false):Void {
    for (record in records) {
      record.launchValidate();
    }
    if (clearAfter) {
      clear();
    }
  }
}
