package quadrants;

abstract Spec<T>(T) from T to T {
  public inline function new(value:T) {
    this = value;
  }

  public static inline function of<T>(value:T):Spec<T> {
    return new Spec(value);
  }

  public inline function value():T {
    return this;
  }
}
