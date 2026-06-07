package quadrants.kernel;

interface ArgEncoder<T> {
  public function append(buf:ArgBuffer, value:T):Void;
  public function specFragment(value:T):String;
}

private class DefaultArgEncoder<T> implements ArgEncoder<T> {
  public function new() {}

  public function append(buf:ArgBuffer, value:T):Void {
    buf.addValue(value);
  }

  public function specFragment(value:T):String {
    return quadrants.kernel.ArgEncoding.specFragment(value);
  }
}

class ArgEncoderTools {
  public static function encoder<T>():ArgEncoder<T> {
    return new DefaultArgEncoder();
  }
}
