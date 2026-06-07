package quadrants.simt;

import quadrants.Block;
import quadrants.Tensor;
import quadrants.Types.F64;

class Tile16x16F64 {
  @:qdFunc
  public static function loadTile16x16F64(tile:Tensor<F64>, source:Tensor<F64>, base:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var col:Int = lane - (row << 4);
      tile.kernelWrite(lane, source.kernelRead(base + row * stride + col));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function storeTile16x16F64(tile:Tensor<F64>, target:Tensor<F64>, base:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var col:Int = lane - (row << 4);
      target.kernelWrite(base + row * stride + col, tile.kernelRead(lane));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function transposeTile16x16F64(tile:Tensor<F64>):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var col:Int = lane - (row << 4);
      if (row < col) {
        var a:F64 = tile.kernelRead(row * 16 + col);
        var b:F64 = tile.kernelRead(col * 16 + row);
        tile.kernelWrite(row * 16 + col, b);
        tile.kernelWrite(col * 16 + row, a);
      }
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function outerProductSubtractTile16x16F64(tile:Tensor<F64>, left:Tensor<F64>, right:Tensor<F64>, scale:F64):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var col:Int = lane - (row << 4);
      var current:F64 = tile.kernelRead(lane);
      tile.kernelWrite(lane, (current : Float) - (scale : Float) * (left.kernelRead(row) : Float) * (right.kernelRead(col) : Float));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function choleskyTile16x16F64(tile:Tensor<F64>):Int {
    var lane:Int = Block.threadIdx();
    if (lane == 0) {
      var i:Int = 0;
      while (i < 16) {
        var j:Int = 0;
        while (j <= i) {
          var sum:F64 = tile.kernelRead(i * 16 + j);
          var k:Int = 0;
          while (k < j) {
            sum = (sum : Float) - (tile.kernelRead(i * 16 + k) : Float) * (tile.kernelRead(j * 16 + k) : Float);
            k = k + 1;
          }
          if (i == j) {
            tile.kernelWrite(i * 16 + j, Math.sqrt(sum));
          } else {
            tile.kernelWrite(i * 16 + j, (sum : Float) / (tile.kernelRead(j * 16 + j) : Float));
          }
          j = j + 1;
        }
        var upper:Int = i + 1;
        while (upper < 16) {
          tile.kernelWrite(i * 16 + upper, 0.0);
          upper = upper + 1;
        }
        i = i + 1;
      }
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function solveTriangularTile16x16F64(tile:Tensor<F64>, rhs:Tensor<F64>):Int {
    var lane:Int = Block.threadIdx();
    if (lane == 0) {
      var i:Int = 0;
      while (i < 16) {
        var sum:F64 = rhs.kernelRead(i);
        var k:Int = 0;
        while (k < i) {
          sum = (sum : Float) - (tile.kernelRead(i * 16 + k) : Float) * (rhs.kernelRead(k) : Float);
          k = k + 1;
        }
        rhs.kernelWrite(i, (sum : Float) / (tile.kernelRead(i * 16 + i) : Float));
        i = i + 1;
      }
    }
    Block.sync();
    return 0;
  }
}
