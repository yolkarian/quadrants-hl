package quadrants;

private class VectorData<T> {
  public final values:Array<T>;

  public function new(values:Array<T>) {
    this.values = values;
  }
}

abstract Vector<T>(VectorData<T>) {
  public inline function new(values:Array<T>) {
    this = new VectorData(values.copy());
  }

  public static inline function ofArray<T>(values:Array<T>):Vector<T> {
    return new Vector(values);
  }

  public var length(get, never):Int;
  inline function get_length():Int return this.values.length;

  @:arrayAccess public inline function get(index:Int):T {
    return this.values[index];
  }

  @:arrayAccess public inline function set(index:Int, value:T):T {
    this.values[index] = value;
    return value;
  }

  public inline function toArray():Array<T> {
    return this.values.copy();
  }

  public function map(f:T->T):Vector<T> {
    return new Vector([for (value in this.values) f(value)]);
  }

  public function zip(other:Vector<T>, f:T->T->T):Vector<T> {
    if (length != other.length) {
      throw "Quadrants vector length mismatch";
    }
    return new Vector([for (i in 0...length) f(this.values[i], other.get(i))]);
  }

  @:op(A + B) static function add<T>(lhs:Vector<T>, rhs:Vector<T>):Vector<T> {
    return lhs.zip(rhs, function(a:T, b:T):T {
      var da:Dynamic = a;
      var db:Dynamic = b;
      return cast (da + db);
    });
  }

  @:op(A - B) static function sub<T>(lhs:Vector<T>, rhs:Vector<T>):Vector<T> {
    return lhs.zip(rhs, function(a:T, b:T):T {
      var da:Dynamic = a;
      var db:Dynamic = b;
      return cast (da - db);
    });
  }

  @:op(A * B) static function mul<T>(lhs:Vector<T>, rhs:Vector<T>):Vector<T> {
    return lhs.zip(rhs, function(a:T, b:T):T {
      var da:Dynamic = a;
      var db:Dynamic = b;
      return cast (da * db);
    });
  }
  public function dot(other:Vector<T>):Float {
    if (length != other.length) {
      throw "Quadrants vector length mismatch";
    }
    var total = 0.0;
    for (i in 0...length) {
      var a:Dynamic = this.values[i];
      var b:Dynamic = other.get(i);
      total += a * b;
    }
    return total;
  }

  public function norm():Float {
    return Math.sqrt(dot(cast this));
  }

  public function normalized():Vector<Float> {
    var n = norm();
    if (n == 0.0) {
      throw "Quadrants cannot normalize a zero-length vector";
    }
    return new Vector([for (value in this.values) {
      var d:Dynamic = value;
      d / n;
    }]);
  }

  public function cross(other:Vector<T>):Vector<Float> {
    if (length != 3 || other.length != 3) {
      throw "Quadrants cross product requires two 3D vectors";
    }
    var ax:Dynamic = this.values[0];
    var ay:Dynamic = this.values[1];
    var az:Dynamic = this.values[2];
    var bx:Dynamic = other.get(0);
    var by:Dynamic = other.get(1);
    var bz:Dynamic = other.get(2);
    return new Vector([
      ay * bz - az * by,
      az * bx - ax * bz,
      ax * by - ay * bx,
    ]);
  }

}
