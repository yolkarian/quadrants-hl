package quadrants;

class Ndrange {
  @:deprecated("Use Ndrange.of1/of2/of3/of4 instead.")
  public static function of(a:Int, ?b:Int, ?c:Int, ?d:Int):NdrangeDomain {
    return cast null;
  }

  @:deprecated("Use Ndrange.ranges1/ranges2/ranges3/ranges4 instead.")
  public static function ranges(begin0:Int, end0:Int, ?begin1:Int, ?end1:Int, ?begin2:Int, ?end2:Int, ?begin3:Int, ?end3:Int):NdrangeDomain {
    return cast null;
  }

  public static inline function of1(a:Int):Ndrange1 {
    return cast null;
  }

  public static inline function of2(a:Int, b:Int):Ndrange2 {
    return cast null;
  }

  public static inline function of3(a:Int, b:Int, c:Int):Ndrange3 {
    return cast null;
  }

  public static inline function of4(a:Int, b:Int, c:Int, d:Int):Ndrange4 {
    return cast null;
  }

  public static inline function of1Axes(a:Int, axes:AxisOrder1):Ndrange1 {
    return cast null;
  }

  public static inline function of2Axes(a:Int, b:Int, axes:AxisOrder2):Ndrange2 {
    return cast null;
  }

  public static inline function of3Axes(a:Int, b:Int, c:Int, axes:AxisOrder3):Ndrange3 {
    return cast null;
  }

  public static inline function of4Axes(a:Int, b:Int, c:Int, d:Int, axes:AxisOrder4):Ndrange4 {
    return cast null;
  }

  public static inline function ranges1(begin0:Int, end0:Int):Ndrange1 {
    return cast null;
  }

  public static inline function ranges2(begin0:Int, end0:Int, begin1:Int, end1:Int):Ndrange2 {
    return cast null;
  }

  public static inline function ranges3(begin0:Int, end0:Int, begin1:Int, end1:Int, begin2:Int, end2:Int):Ndrange3 {
    return cast null;
  }

  public static inline function ranges4(begin0:Int, end0:Int, begin1:Int, end1:Int, begin2:Int, end2:Int, begin3:Int, end3:Int):Ndrange4 {
    return cast null;
  }

  public static inline function ranges1Axes(begin0:Int, end0:Int, axes:AxisOrder1):Ndrange1 {
    return cast null;
  }

  public static inline function ranges2Axes(begin0:Int, end0:Int, begin1:Int, end1:Int, axes:AxisOrder2):Ndrange2 {
    return cast null;
  }

  public static inline function ranges3Axes(begin0:Int, end0:Int, begin1:Int, end1:Int, begin2:Int, end2:Int, axes:AxisOrder3):Ndrange3 {
    return cast null;
  }

  public static inline function ranges4Axes(begin0:Int, end0:Int, begin1:Int, end1:Int, begin2:Int, end2:Int, begin3:Int, end3:Int, axes:AxisOrder4):Ndrange4 {
    return cast null;
  }
}
