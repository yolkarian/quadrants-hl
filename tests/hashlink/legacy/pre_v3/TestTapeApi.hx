import quadrants.Tape;

class TestTapeApi {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var tape = new Tape();
    expectEq("tape_initial_length", tape.length, 0);
    tape.pause();
    tape.record(null, []);
    expectEq("tape_pause_skips_record", tape.length, 0);
    tape.resume();
    var rejectedNull = false;
    try {
      tape.record(null, []);
    } catch (_:Dynamic) {
      rejectedNull = true;
    }
    if (!rejectedNull) throw "tape should reject null kernels while recording";
    tape.clear();
    tape.validate(true);
    expectEq("tape_clear", tape.length, 0);
  }
}
