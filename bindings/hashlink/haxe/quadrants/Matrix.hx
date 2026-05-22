package quadrants;

class Matrix<T> {
  public final rows:Int;
  public final cols:Int;
  final values:Array<T>;

  public function new(rows:Int, cols:Int, values:Array<T>) {
    if (rows <= 0 || cols <= 0) {
      throw "Quadrants matrix dimensions must be positive";
    }
    if (values.length != rows * cols) {
      throw "Quadrants matrix value count mismatch";
    }
    this.rows = rows;
    this.cols = cols;
    this.values = [for (value in values) value];
  }


  public static function ofArray<T>(rows:Int, cols:Int, values:Array<T>):Matrix<T> {
    return new Matrix(rows, cols, values);
  }
  public static function filled<T>(rows:Int, cols:Int, value:T):Matrix<T> {
    return new Matrix(rows, cols, [for (_ in 0...(rows * cols)) value]);
  }

  inline function flatIndex(row:Int, col:Int):Int {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw "Quadrants matrix index out of bounds";
    }
    return row * cols + col;
  }

  public inline function get(row:Int, col:Int):T {
    return values[flatIndex(row, col)];
  }

  public inline function set(row:Int, col:Int, value:T):T {
    values[flatIndex(row, col)] = value;
    return value;
  }

  public function toArray():Array<T> {
    return [for (value in values) value];
  }

  public function zip(other:Matrix<T>, f:T->T->T):Matrix<T> {
    if (rows != other.rows || cols != other.cols) {
      throw "Quadrants matrix shape mismatch";
    }
    return new Matrix(rows, cols, [for (i in 0...values.length) f(values[i], other.values[i])]);
  }

  public function add(other:Matrix<T>):Matrix<T> {
    return zip(other, function(a:T, b:T):T {
      var da:Dynamic = a;
      var db:Dynamic = b;
      return cast (da + db);
    });
  }

  public function sub(other:Matrix<T>):Matrix<T> {
    return zip(other, function(a:T, b:T):T {
      var da:Dynamic = a;
      var db:Dynamic = b;
      return cast (da - db);
    });
  }

  public function mul(other:Matrix<T>):Matrix<T> {
    return zip(other, function(a:T, b:T):T {
      var da:Dynamic = a;
      var db:Dynamic = b;
      return cast (da * db);
    });
  }

  public function transpose():Matrix<T> {
    return new Matrix(cols, rows, [for (col in 0...cols) for (row in 0...rows) values[flatIndex(row, col)]]);
  }

  public function matmul(other:Matrix<T>):Matrix<Float> {
    if (cols != other.rows) {
      throw "Quadrants matrix multiply shape mismatch";
    }
    var out = new Array<Float>();
    for (row in 0...rows) {
      for (col in 0...other.cols) {
        var total = 0.0;
        for (k in 0...cols) {
          var a:Dynamic = values[flatIndex(row, k)];
          var b:Dynamic = other.get(k, col);
          total += a * b;
        }
        out.push(total);
      }
    }
    return new Matrix(rows, other.cols, out);
  }

}
