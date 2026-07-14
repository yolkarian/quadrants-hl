package quadrants.funcs;

import quadrants.Matrix;
import quadrants.Vector;

typedef SvdResult<T> = {
  var u:Matrix<T>;
  var sigma:Vector<T>;
  var v:Matrix<T>;
}

typedef EigResult<T> = {
  var values:Vector<T>;
  var vectors:Matrix<T>;
}

class Linalg {
  static inline var EPS = 1.0e-10;

  public static function svd2<T>(m:Matrix<T>):SvdResult<T> {
    requireShape(m, 2, 2, "svd2");
    return cast svd(m, 2);
  }

  public static function svd3<T>(m:Matrix<T>):SvdResult<T> {
    requireShape(m, 3, 3, "svd3");
    return cast svd(m, 3);
  }

  public static function symEig2<T>(m:Matrix<T>):EigResult<T> {
    requireShape(m, 2, 2, "symEig2");
    return cast symEig2Float(toFloatArray(m));
  }

  public static function symEig3<T>(m:Matrix<T>):EigResult<T> {
    requireShape(m, 3, 3, "symEig3");
    return cast symEig3Float(toFloatArray(m));
  }

  public static function symEigGeneral<T>(m:Matrix<T>):EigResult<T> {
    if (m == null || m.rows != m.cols || m.rows < 1) {
      throw "Quadrants Linalg.symEigGeneral requires a square matrix";
    }
    var n = m.rows;
    if (n == 2) {
      return symEig2(m);
    }
    if (n == 3) {
      return symEig3(m);
    }
    var result = symEigGeneralFloat(toFloatArray(m), n);
    return cast {values: vector(result.values), vectors: matrix(n, n, result.vectors)};
  }

  public static function eig2<T>(m:Matrix<T>):EigResult<T> {
    requireShape(m, 2, 2, "eig2");
    var a = f(m.get(0, 0));
    var b = f(m.get(0, 1));
    var c = f(m.get(1, 0));
    var d = f(m.get(1, 1));
    var tr = a + d;
    var det = a * d - b * c;
    var disc = tr * tr - 4.0 * det;
    if (disc < -EPS) {
      throw "Quadrants Linalg.eig2 real-valued API cannot represent complex eigenvalues";
    }
    var root = Math.sqrt(Math.max(0.0, disc));
    var l0 = 0.5 * (tr + root);
    var l1 = 0.5 * (tr - root);
    var v0 = eigenvector2(a, b, c, d, l0);
    var v1 = Math.abs(l0 - l1) <= EPS ? orthogonal2(v0) : eigenvector2(a, b, c, d, l1);
    return cast {
      values: vector([l0, l1]),
      vectors: matrix(2, 2, [v0[0], v1[0], v0[1], v1[1]]),
    };
  }

  public static function polar2<T>(m:Matrix<T>):{var u:Matrix<T>; var p:Matrix<T>;} {
    requireShape(m, 2, 2, "polar2");
    var result = polar(m, 2);
    return cast result;
  }

  public static function polar3<T>(m:Matrix<T>):{var u:Matrix<T>; var p:Matrix<T>;} {
    requireShape(m, 3, 3, "polar3");
    var result = polar(m, 3);
    return cast result;
  }

  public static function solve2<T>(a:Matrix<T>, b:Vector<T>):Vector<T> {
    requireShape(a, 2, 2, "solve2");
    requireVector(b, 2, "solve2");
    return cast vector(solveLinear(toFloatArray(a), vectorToFloatArray(b), 2));
  }

  public static function solve3<T>(a:Matrix<T>, b:Vector<T>):Vector<T> {
    requireShape(a, 3, 3, "solve3");
    requireVector(b, 3, "solve3");
    return cast vector(solveLinear(toFloatArray(a), vectorToFloatArray(b), 3));
  }

  public static function makeSpd<T>(a:Matrix<T>):Matrix<T> {
    if (a == null || a.rows != a.cols || a.rows < 2) {
      throw "Quadrants Linalg.makeSpd requires a square matrix of size 2 or larger";
    }
    var n = a.rows;
    var sym = new Array<Float>();
    for (row in 0...n) {
      for (col in 0...n) {
        sym.push(0.5 * (f(a.get(row, col)) + f(a.get(col, row))));
      }
    }
    var eig = if (n == 2) {
      symEig2Float(sym);
    } else if (n == 3) {
      symEig3Float(sym);
    } else {
      var general = symEigGeneralFloat(sym, n);
      {values: (cast vector(general.values) : Vector<Float>), vectors: (cast matrix(n, n, general.vectors) : Matrix<Float>)};
    };
    var values = eig.values.toArray();
    var vectors = toFloatArray(eig.vectors);
    var clamped = [for (value in values) Math.max(f(value), EPS)];
    return cast matrix(n, n, multiplyMatrices(multiplyMatrices(vectors, diagonal(clamped, n), n), transpose(vectors, n), n));
  }

  static function symEigGeneralFloat(source:Array<Float>, n:Int):{values:Array<Float>, vectors:Array<Float>} {
    var maxSweeps = 30;
    var work = [for (value in source) value];
    var vectors = [for (row in 0...n) for (col in 0...n) row == col ? 1.0 : 0.0];
    inline function at(row:Int, col:Int):Int return row * n + col;

    var scale = 0.0;
    for (value in work) {
      var magnitude = Math.abs(value);
      if (magnitude > scale) {
        scale = magnitude;
      }
    }
    // Skip rotations for pivots that are negligible relative to the matrix
    // scale (double-precision noise floor), with an absolute floor for the
    // all-zero matrix. A fixed absolute threshold would silently return the
    // diagonal for matrices whose overall scale is below it.
    var considerAsZero = Math.max(1.0e-300, scale * 1.0e-15);
    var converged = scale == 0.0;

    for (_ in 0...maxSweeps) {
      if (converged) {
        break;
      }
      var rotated = false;
      for (p in 0...n) {
        for (q in (p + 1)...n) {
          var apq = work[at(p, q)];
          if (Math.abs(apq) <= considerAsZero) {
            continue;
          }
          rotated = true;
          var app = work[at(p, p)];
          var aqq = work[at(q, q)];
          var diff = aqq - app;
          var tau = 1.0;
          if (Math.abs(diff) < considerAsZero) {
            if (apq < 0.0) {
              tau = -1.0;
            }
          } else {
            var theta = diff / (2.0 * apq);
            tau = 1.0 / (Math.abs(theta) + Math.sqrt(1.0 + theta * theta));
            if (theta < 0.0) {
              tau = -tau;
            }
          }
          var gc = 1.0 / Math.sqrt(1.0 + tau * tau);
          var gs = tau * gc;
          for (r in 0...n) {
            var arp = work[at(r, p)];
            var arq = work[at(r, q)];
            work[at(r, p)] = gc * arp - gs * arq;
            work[at(r, q)] = gs * arp + gc * arq;
          }
          for (k in 0...n) {
            var akp = work[at(p, k)];
            var akq = work[at(q, k)];
            work[at(p, k)] = gc * akp - gs * akq;
            work[at(q, k)] = gs * akp + gc * akq;
          }
          work[at(p, q)] = 0.0;
          work[at(q, p)] = 0.0;
          for (r in 0...n) {
            var vrp = vectors[at(r, p)];
            var vrq = vectors[at(r, q)];
            vectors[at(r, p)] = gc * vrp - gs * vrq;
            vectors[at(r, q)] = gs * vrp + gc * vrq;
          }
        }
      }
      if (!rotated) {
        converged = true;
      }
    }
    if (!converged) {
      var maxOffDiagonal = 0.0;
      for (p in 0...n) {
        for (q in (p + 1)...n) {
          var magnitude = Math.abs(work[at(p, q)]);
          if (magnitude > maxOffDiagonal) {
            maxOffDiagonal = magnitude;
          }
        }
      }
      if (maxOffDiagonal > scale * 1.0e-10) {
        throw "Quadrants Linalg.symEigGeneral did not converge";
      }
    }
    var values = [for (i in 0...n) work[at(i, i)]];
    for (i in 0...n) {
      var minIndex = i;
      var minValue = values[i];
      for (j in (i + 1)...n) {
        if (values[j] < minValue) {
          minValue = values[j];
          minIndex = j;
        }
      }
      if (minIndex != i) {
        values[minIndex] = values[i];
        values[i] = minValue;
        for (k in 0...n) {
          var tmp = vectors[at(k, i)];
          vectors[at(k, i)] = vectors[at(k, minIndex)];
          vectors[at(k, minIndex)] = tmp;
        }
      }
    }
    return {values: values, vectors: vectors};
  }

  static function svd<T>(m:Matrix<T>, n:Int):SvdResult<Float> {
    var a = toFloatArray(m);
    var ata = multiplyMatrices(transpose(a, n), a, n);
    var eig = n == 2 ? symEig2Float(ata) : symEig3Float(ata);
    var lambda = [for (value in eig.values.toArray()) Math.max(0.0, f(value))];
    var sigma = [for (value in lambda) Math.sqrt(value)];
    var v = toFloatArray(eig.vectors);
    var uCols = new Array<Array<Float>>();
    for (col in 0...n) {
      var vc = column(v, n, col);
      var av = matVec(a, vc, n);
      if (sigma[col] > EPS) {
        uCols.push(scale(av, 1.0 / sigma[col]));
      } else {
        uCols.push(null);
      }
    }
    completeOrthonormalColumns(uCols, n);
    var u = columnsToMatrix(uCols, n);
    return {
      u: matrix(n, n, u),
      sigma: vector(sigma),
      v: matrix(n, n, v),
    };
  }

  static function polar<T>(m:Matrix<T>, n:Int):{var u:Matrix<Float>; var p:Matrix<Float>;} {
    var s = svd(m, n);
    var u = toFloatArray(s.u);
    var v = toFloatArray(s.v);
    var sigma = [for (value in s.sigma.toArray()) f(value)];
    var r = multiplyMatrices(u, transpose(v, n), n);
    var p = multiplyMatrices(multiplyMatrices(v, diagonal(sigma, n), n), transpose(v, n), n);
    return {u: matrix(n, n, r), p: matrix(n, n, p)};
  }

  static function symEig2Float(a:Array<Float>):EigResult<Float> {
    var aa = a[0];
    var bb = 0.5 * (a[1] + a[2]);
    var dd = a[3];
    var mid = 0.5 * (aa + dd);
    var delta = Math.sqrt(0.25 * (aa - dd) * (aa - dd) + bb * bb);
    var l0 = mid + delta;
    var l1 = mid - delta;
    var v0 = symmetricEigenvector2(aa, bb, dd, l0);
    var v1 = orthogonal2(v0);
    return {
      values: vector([l0, l1]),
      vectors: matrix(2, 2, [v0[0], v1[0], v0[1], v1[1]]),
    };
  }

  static function symEig3Float(input:Array<Float>):EigResult<Float> {
    var a = input.copy();
    a[1] = a[3] = 0.5 * (a[1] + a[3]);
    a[2] = a[6] = 0.5 * (a[2] + a[6]);
    a[5] = a[7] = 0.5 * (a[5] + a[7]);
    var v = identity(3);
    for (_ in 0...48) {
      var p = 0;
      var q = 1;
      var best = Math.abs(a[1]);
      var a02 = Math.abs(a[2]);
      if (a02 > best) {
        p = 0; q = 2; best = a02;
      }
      var a12 = Math.abs(a[5]);
      if (a12 > best) {
        p = 1; q = 2; best = a12;
      }
      if (best <= EPS) {
        break;
      }
      jacobiRotate(a, v, 3, p, q);
    }
    var order = [0, 1, 2];
    order.sort(function(lhs, rhs) return compareFloatDesc(a[lhs * 3 + lhs], a[rhs * 3 + rhs]));
    var values = [for (idx in order) a[idx * 3 + idx]];
    var vectors = new Array<Float>();
    for (row in 0...3) {
      for (col in 0...3) {
        vectors.push(v[row * 3 + order[col]]);
      }
    }
    return {values: vector(values), vectors: matrix(3, 3, vectors)};
  }

  static function jacobiRotate(a:Array<Float>, v:Array<Float>, n:Int, p:Int, q:Int):Void {
    var app = a[p * n + p];
    var aqq = a[q * n + q];
    var apq = a[p * n + q];
    if (Math.abs(apq) <= EPS) return;
    var phi = 0.5 * Math.atan2(2.0 * apq, aqq - app);
    var c = Math.cos(phi);
    var s = Math.sin(phi);
    for (k in 0...n) {
      var akp = a[k * n + p];
      var akq = a[k * n + q];
      a[k * n + p] = c * akp - s * akq;
      a[k * n + q] = s * akp + c * akq;
    }
    for (k in 0...n) {
      var apk = a[p * n + k];
      var aqk = a[q * n + k];
      a[p * n + k] = c * apk - s * aqk;
      a[q * n + k] = s * apk + c * aqk;
    }
    a[p * n + q] = 0.0;
    a[q * n + p] = 0.0;
    for (k in 0...n) {
      var vkp = v[k * n + p];
      var vkq = v[k * n + q];
      v[k * n + p] = c * vkp - s * vkq;
      v[k * n + q] = s * vkp + c * vkq;
    }
  }

  static function solveLinear(a:Array<Float>, b:Array<Float>, n:Int):Array<Float> {
    var m = a.copy();
    var rhs = b.copy();
    for (pivot in 0...n) {
      var best = pivot;
      var bestAbs = Math.abs(m[pivot * n + pivot]);
      for (row in pivot + 1...n) {
        var value = Math.abs(m[row * n + pivot]);
        if (value > bestAbs) {
          best = row;
          bestAbs = value;
        }
      }
      if (bestAbs <= EPS) {
        throw "Quadrants Linalg.solve encountered a singular matrix";
      }
      if (best != pivot) {
        for (col in 0...n) {
          var tmp = m[pivot * n + col];
          m[pivot * n + col] = m[best * n + col];
          m[best * n + col] = tmp;
        }
        var r = rhs[pivot];
        rhs[pivot] = rhs[best];
        rhs[best] = r;
      }
      var diag = m[pivot * n + pivot];
      for (col in pivot...n) m[pivot * n + col] /= diag;
      rhs[pivot] /= diag;
      for (row in 0...n) {
        if (row == pivot) continue;
        var factor = m[row * n + pivot];
        if (factor == 0.0) continue;
        for (col in pivot...n) m[row * n + col] -= factor * m[pivot * n + col];
        rhs[row] -= factor * rhs[pivot];
      }
    }
    return rhs;
  }

  static function completeOrthonormalColumns(columns:Array<Array<Float>>, n:Int):Void {
    for (i in 0...n) {
      var col = columns[i];
      if (col == null || norm(col) <= EPS) {
        col = basisVector(n, i);
      }
      for (j in 0...i) {
        var prev = columns[j];
        col = sub(col, scale(prev, dot(col, prev)));
      }
      var len = norm(col);
      if (len <= EPS) {
        for (candidate in 0...n) {
          col = basisVector(n, candidate);
          for (j in 0...i) col = sub(col, scale(columns[j], dot(col, columns[j])));
          len = norm(col);
          if (len > EPS) break;
        }
      }
      if (len <= EPS) {
        throw "Quadrants Linalg.svd failed to build an orthonormal basis";
      }
      columns[i] = scale(col, 1.0 / len);
    }
    if (n == 3 && determinant3(columnsToMatrix(columns, 3)) < 0.0) {
      columns[2] = scale(columns[2], -1.0);
    }
  }

  static function eigenvector2(a:Float, b:Float, c:Float, d:Float, lambda:Float):Array<Float> {
    var x = Math.abs(b) > Math.abs(c) ? b : lambda - d;
    var y = Math.abs(b) > Math.abs(c) ? lambda - a : c;
    return normalize2([x, y]);
  }

  static function symmetricEigenvector2(a:Float, b:Float, d:Float, lambda:Float):Array<Float> {
    if (Math.abs(b) <= EPS) {
      return a >= d ? [1.0, 0.0] : [0.0, 1.0];
    }
    return normalize2([b, lambda - a]);
  }

  static function normalize2(v:Array<Float>):Array<Float> {
    var len = Math.sqrt(v[0] * v[0] + v[1] * v[1]);
    if (len <= EPS) return [1.0, 0.0];
    return [v[0] / len, v[1] / len];
  }

  static inline function orthogonal2(v:Array<Float>):Array<Float> {
    return [-v[1], v[0]];
  }

  static function compareFloatDesc(a:Float, b:Float):Int {
    return a > b ? -1 : a < b ? 1 : 0;
  }

  static function requireShape<T>(m:Matrix<T>, rows:Int, cols:Int, name:String):Void {
    if (m == null || m.rows != rows || m.cols != cols) {
      throw 'Quadrants Linalg.${name} requires a ${rows}x${cols} matrix';
    }
  }

  static function requireVector<T>(v:Vector<T>, length:Int, name:String):Void {
    if (v == null || v.length != length) {
      throw 'Quadrants Linalg.${name} requires a vector of length ${length}';
    }
  }

  static function toFloatArray<T>(m:Matrix<T>):Array<Float> {
    return [for (value in m.toArray()) f(value)];
  }

  static function vectorToFloatArray<T>(v:Vector<T>):Array<Float> {
    return [for (value in v.toArray()) f(value)];
  }

  static inline function f<T>(value:T):Float {
    var d:Dynamic = value;
    return d;
  }

  static function matrix<T>(rows:Int, cols:Int, values:Array<Float>):Matrix<T> {
    return cast Matrix.ofArray(rows, cols, [for (value in values) cast value]);
  }

  static function vector<T>(values:Array<Float>):Vector<T> {
    return cast Vector.ofArray([for (value in values) cast value]);
  }

  static function identity(n:Int):Array<Float> {
    return [for (row in 0...n) for (col in 0...n) row == col ? 1.0 : 0.0];
  }

  static function diagonal(values:Array<Float>, n:Int):Array<Float> {
    return [for (row in 0...n) for (col in 0...n) row == col ? values[row] : 0.0];
  }

  static function transpose(a:Array<Float>, n:Int):Array<Float> {
    return [for (row in 0...n) for (col in 0...n) a[col * n + row]];
  }

  static function multiplyMatrices(a:Array<Float>, b:Array<Float>, n:Int):Array<Float> {
    return [for (row in 0...n) for (col in 0...n) {
      var total = 0.0;
      for (k in 0...n) total += a[row * n + k] * b[k * n + col];
      total;
    }];
  }

  static function matVec(a:Array<Float>, v:Array<Float>, n:Int):Array<Float> {
    return [for (row in 0...n) {
      var total = 0.0;
      for (col in 0...n) total += a[row * n + col] * v[col];
      total;
    }];
  }

  static function column(a:Array<Float>, n:Int, col:Int):Array<Float> {
    return [for (row in 0...n) a[row * n + col]];
  }

  static function columnsToMatrix(columns:Array<Array<Float>>, n:Int):Array<Float> {
    return [for (row in 0...n) for (col in 0...n) columns[col][row]];
  }

  static function basisVector(n:Int, index:Int):Array<Float> {
    return [for (i in 0...n) i == index ? 1.0 : 0.0];
  }

  static function dot(a:Array<Float>, b:Array<Float>):Float {
    var total = 0.0;
    for (i in 0...a.length) total += a[i] * b[i];
    return total;
  }

  static function norm(a:Array<Float>):Float {
    return Math.sqrt(dot(a, a));
  }

  static function scale(a:Array<Float>, value:Float):Array<Float> {
    return [for (entry in a) entry * value];
  }

  static function sub(a:Array<Float>, b:Array<Float>):Array<Float> {
    return [for (i in 0...a.length) a[i] - b[i]];
  }

  static function determinant3(a:Array<Float>):Float {
    return a[0] * (a[4] * a[8] - a[5] * a[7])
      - a[1] * (a[3] * a[8] - a[5] * a[6])
      + a[2] * (a[3] * a[7] - a[4] * a[6]);
  }
}
