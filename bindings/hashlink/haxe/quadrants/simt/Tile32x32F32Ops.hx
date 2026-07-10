package quadrants.simt;

import quadrants.Block;
import quadrants.Tensor;
import quadrants.Types.F32;

/** Portable shared-memory extensions for a flat 32x32 F32 tile. */
class Tile32x32F32Ops {
  @:qdFunc
  public static function zeroTile32x32F32(tile:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) tile.kernelWrite(lane, 0.0);
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function identityTile32x32F32(tile:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var column:Int = lane & 31;
      var value:F32 = 0.0;
      if (row == column) value = 1.0;
      tile.kernelWrite(lane, value);
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function getColumnTile32x32F32(tile:Tensor<F32>, column:Int):F32 {
    var row:Int = Block.threadIdx();
    var result:F32 = 0.0;
    if (row >= 0 && row < 32 && column >= 0 && column < 32) {
      result = tile.kernelRead(row * 32 + column);
    }
    return result;
  }

  @:qdFunc
  public static function setColumnTile32x32F32(tile:Tensor<F32>, column:Int, value:F32):Int {
    var row:Int = Block.threadIdx();
    if (row >= 0 && row < 32 && column >= 0 && column < 32) {
      tile.kernelWrite(row * 32 + column, value);
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function loadTile32x32F32Batched(tile:Tensor<F32>, source:Tensor<F32>, batch:Int, base:Int, batchStride:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var column:Int = lane & 31;
      tile.kernelWrite(lane, source.kernelRead(base + batch * batchStride + row * stride + column));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function storeTile32x32F32Batched(tile:Tensor<F32>, target:Tensor<F32>, batch:Int, base:Int, batchStride:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 1024) {
      var row:Int = lane >> 5;
      var column:Int = lane & 31;
      target.kernelWrite(base + batch * batchStride + row * stride + column, tile.kernelRead(lane));
    }
    Block.sync();
    return 0;
  }
}
