package quadrants.simt;

import quadrants.Block;
import quadrants.Tensor;
import quadrants.Types.F32;

class Tile32x32F32 {
  @:qdFunc
  public static function loadTile32x32F32(tile:Tensor<F32>, source:Tensor<F32>, base:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var col:Int = lane - (row << 5);
      tile.kernelWrite(lane, source.kernelRead(base + row * stride + col));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function storeTile32x32F32(tile:Tensor<F32>, target:Tensor<F32>, base:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var col:Int = lane - (row << 5);
      target.kernelWrite(base + row * stride + col, tile.kernelRead(lane));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function transposeTile32x32F32(tile:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var col:Int = lane - (row << 5);
      if (row < col) {
        var a:F32 = tile.kernelRead(row * 32 + col);
        var b:F32 = tile.kernelRead(col * 32 + row);
        tile.kernelWrite(row * 32 + col, b);
        tile.kernelWrite(col * 32 + row, a);
      }
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function outerProductSubtractTile32x32F32(tile:Tensor<F32>, left:Tensor<F32>, right:Tensor<F32>, scale:F32):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var col:Int = lane - (row << 5);
      var current:F32 = tile.kernelRead(lane);
      tile.kernelWrite(lane, (current : Float) - (scale : Float) * (left.kernelRead(row) : Float) * (right.kernelRead(col) : Float));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function choleskyTile32x32F32(tile:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane == 0) {
      var i:Int = 0;
      while (i < 32) {
        var j:Int = 0;
        while (j <= i) {
          var sum:F32 = tile.kernelRead(i * 32 + j);
          var k:Int = 0;
          while (k < j) {
            sum = (sum : Float) - (tile.kernelRead(i * 32 + k) : Float) * (tile.kernelRead(j * 32 + k) : Float);
            k = k + 1;
          }
          if (i == j) {
            tile.kernelWrite(i * 32 + j, Math.sqrt(sum));
          } else {
            tile.kernelWrite(i * 32 + j, (sum : Float) / (tile.kernelRead(j * 32 + j) : Float));
          }
          j = j + 1;
        }
        var upper:Int = i + 1;
        while (upper < 32) {
          tile.kernelWrite(i * 32 + upper, 0.0);
          upper = upper + 1;
        }
        i = i + 1;
      }
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function solveTriangularTile32x32F32(tile:Tensor<F32>, rhs:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane == 0) {
      var i:Int = 0;
      while (i < 32) {
        var sum:F32 = rhs.kernelRead(i);
        var k:Int = 0;
        while (k < i) {
          sum = (sum : Float) - (tile.kernelRead(i * 32 + k) : Float) * (rhs.kernelRead(k) : Float);
          k = k + 1;
        }
        rhs.kernelWrite(i, (sum : Float) / (tile.kernelRead(i * 32 + i) : Float));
        i = i + 1;
      }
    }
    Block.sync();
    return 0;
  }
}
