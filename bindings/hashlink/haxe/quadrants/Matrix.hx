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

  public static function diag<T>(diagonal:Vector<T>):Matrix<Float> {
    var n = diagonal.length;
    if (n <= 0 || n > 4) {
      throw "Quadrants diagonal matrix helper supports one to four elements";
    }
    var values = new Array<Float>();
    for (row in 0...n) {
      for (col in 0...n) {
        values.push(row == col ? numeric(diagonal[row]) : 0.0);
      }
    }
    return new Matrix(n, n, values);
  }

  public static function outer<T>(lhs:Vector<T>, rhs:Vector<T>):Matrix<Float> {
    if (lhs.length <= 0 || rhs.length <= 0 || lhs.length > 4 || rhs.length > 4) {
      throw "Quadrants outer product supports one to four elements per vector";
    }
    return new Matrix(lhs.length, rhs.length, [for (row in 0...lhs.length) for (col in 0...rhs.length) numeric(lhs[row]) * numeric(rhs[col])]);
  }

  inline function flatIndex(row:Int, col:Int):Int {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw "Quadrants matrix index out of bounds";
    }
    return row * cols + col;
  }

  @:arrayAccess public inline function getFlat(index:Int):T {
    if (index < 0 || index >= values.length) {
      throw "Quadrants matrix index out of bounds";
    }
    return values[index];
  }

  @:arrayAccess public inline function setFlat(index:Int, value:T):T {
    if (index < 0 || index >= values.length) {
      throw "Quadrants matrix index out of bounds";
    }
    values[index] = value;
    return value;
  }

  public inline function get(row:Int, col:Int):T {
    return values[flatIndex(row, col)];
  }

  public function kernelGet(row:Int, col:Int):T {
    return get(row, col);
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

  public function trace():Float {
    requireSquare("trace");
    var total = 0.0;
    for (i in 0...rows) {
      total += numeric(values[flatIndex(i, i)]);
    }
    return total;
  }

  public function determinant():Float {
    requireSquare("determinant");
    requireSmallSquare("determinant");
    return determinantFrom(values, rows);
  }

  public function frobeniusSquared():Float {
    var total = 0.0;
    for (value in values) {
      var f = numeric(value);
      total += f * f;
    }
    return total;
  }

  public inline function frobeniusNorm():Float {
    return Math.sqrt(frobeniusSquared());
  }

  public inline function frobenius():Float {
    return frobeniusNorm();
  }

  public function diagonal():Vector<T> {
    requireSquare("diagonal");
    return Vector.ofArray([for (i in 0...rows) values[flatIndex(i, i)]]);
  }

  public function matvec(vector:Vector<T>):Vector<Float> {
    if (cols != vector.length) {
      throw "Quadrants matrix-vector multiply shape mismatch";
    }
    if (rows > 4 || cols > 4) {
      throw "Quadrants matrix-vector multiply supports up to four rows and columns";
    }
    return Vector.ofArray([for (row in 0...rows) {
      var total = 0.0;
      for (col in 0...cols) {
        total += numeric(values[flatIndex(row, col)]) * numeric(vector[col]);
      }
      total;
    }]);
  }

  public inline function multiplyVector(vector:Vector<T>):Vector<Float> {
    return matvec(vector);
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
          total += numeric(values[flatIndex(row, k)]) * numeric(other.get(k, col));
        }
        out.push(total);
      }
    }
    return new Matrix(rows, other.cols, out);
  }

  public function inverse():Matrix<Float> {
    requireSquare("inverse");
    requireSmallSquare("inverse");
    var det = determinant();
    if (det == 0.0) {
      throw "Quadrants matrix inverse is singular";
    }
    var out = new Array<Float>();
    for (row in 0...rows) {
      for (col in 0...cols) {
        var cofactor = cofactorAt(col, row);
        out.push(cofactor / det);
      }
    }
    return new Matrix(rows, cols, out);
  }

  function requireSquare(operation:String):Void {
    if (rows != cols) {
      throw 'Quadrants matrix ${operation} requires a square matrix';
    }
  }

  function requireSmallSquare(operation:String):Void {
    if (rows > 4) {
      throw 'Quadrants matrix ${operation} supports sizes 1x1 through 4x4';
    }
  }

  function cofactorAt(row:Int, col:Int):Float {
    if (rows == 1) {
      return 1.0;
    }
    var minor = new Array<T>();
    for (r in 0...rows) {
      if (r == row) continue;
      for (c in 0...cols) {
        if (c != col) minor.push(values[flatIndex(r, c)]);
      }
    }
    var sign = ((row + col) & 1) == 0 ? 1.0 : -1.0;
    return sign * determinantFrom(minor, rows - 1);
  }

  static function determinantFrom<T>(input:Array<T>, dim:Int):Float {
    return switch (dim) {
      case 1:
        numeric(input[0]);
      case 2:
        numeric(input[0]) * numeric(input[3]) - numeric(input[1]) * numeric(input[2]);
      case 3:
        numeric(input[0]) * (numeric(input[4]) * numeric(input[8]) - numeric(input[5]) * numeric(input[7]))
          - numeric(input[1]) * (numeric(input[3]) * numeric(input[8]) - numeric(input[5]) * numeric(input[6]))
          + numeric(input[2]) * (numeric(input[3]) * numeric(input[7]) - numeric(input[4]) * numeric(input[6]));
      case 4:
        var total = 0.0;
        for (col in 0...4) {
          var minor = new Array<T>();
          for (r in 1...4) {
            for (c in 0...4) {
              if (c != col) minor.push(input[r * 4 + c]);
            }
          }
          total += (col & 1) == 0 ? numeric(input[col]) * determinantFrom(minor, 3) : -numeric(input[col]) * determinantFrom(minor, 3);
        }
        total;
      default:
        throw "Quadrants determinant supports sizes 1x1 through 4x4";
    }
  }

  static inline function numeric<T>(value:T):Float {
    var d:Dynamic = value;
    return d;
  }
}
