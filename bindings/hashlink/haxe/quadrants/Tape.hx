package quadrants;

private class TapeRecord {
  public final kernel:Kernel;
  public final args:Array<Dynamic>;

  public function new(kernel:Kernel, args:Array<Dynamic>) {
    if (kernel == null) {
      throw "Quadrants tape cannot record a null kernel";
    }
    this.kernel = kernel;
    this.args = args.copy();
  }
}

class Tape {
  final records:Array<TapeRecord> = [];
  public var recording(default, null):Bool = true;

  public function new() {}

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
      records.push(new TapeRecord(kernel, args));
    }
  }

  public function launch(kernel:Kernel, ...args:Dynamic):Void {
    kernel.launch(...args);
    record(kernel, args);
  }

  public function backward(clearAfter:Bool = false):Void {
    var i = records.length;
    while (i > 0) {
      i--;
      var record = records[i];
      var grad = record.kernel.grad();
      try {
        grad.launch(...record.args);
      } catch (e:Dynamic) {
        grad.close();
        throw e;
      }
      grad.close();
    }
    if (clearAfter) {
      clear();
    }
  }

  public function forward(clearAfter:Bool = false):Void {
    for (record in records) {
      var grad = record.kernel.forwardGrad();
      try {
        grad.launch(...record.args);
      } catch (e:Dynamic) {
        grad.close();
        throw e;
      }
      grad.close();
    }
    if (clearAfter) {
      clear();
    }
  }

  public function validate(clearAfter:Bool = false):Void {
    for (record in records) {
      var validation = record.kernel.validationKernel();
      try {
        validation.launch(...record.args);
      } catch (e:Dynamic) {
        validation.close();
        throw e;
      }
      validation.close();
    }
    if (clearAfter) {
      clear();
    }
  }
}
