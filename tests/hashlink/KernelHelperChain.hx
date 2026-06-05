class KernelHelperChain {
  @:qdFunc
  public static function twiceAfterInc(x:Int):Int {
    return KernelHelperMath.inc(x) * 2;
  }
}
