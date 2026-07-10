package quadrants.simt;

import quadrants.Block;
import quadrants.Tensor;
import quadrants.Types.F32;

/** Portable shared-memory extensions for a flat 16x16 F32 tile. */
class Tile16x16F32Ops {
  @:qdFunc
  public static function zeroTile16x16F32(tile:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) tile.kernelWrite(lane, 0.0);
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function identityTile16x16F32(tile:Tensor<F32>):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var column:Int = lane & 15;
      var value:F32 = 0.0;
      if (row == column) value = 1.0;
      tile.kernelWrite(lane, value);
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function getColumnTile16x16F32(tile:Tensor<F32>, column:Int):F32 {
    var row:Int = Block.threadIdx();
    var result:F32 = 0.0;
    if (row >= 0 && row < 16 && column >= 0 && column < 16) {
      result = tile.kernelRead(row * 16 + column);
    }
    return result;
  }

  @:qdFunc
  public static function setColumnTile16x16F32(tile:Tensor<F32>, column:Int, value:F32):Int {
    var row:Int = Block.threadIdx();
    if (row >= 0 && row < 16 && column >= 0 && column < 16) {
      tile.kernelWrite(row * 16 + column, value);
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function loadTile16x16F32Batched(tile:Tensor<F32>, source:Tensor<F32>, batch:Int, base:Int, batchStride:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var column:Int = lane & 15;
      tile.kernelWrite(lane, source.kernelRead(base + batch * batchStride + row * stride + column));
    }
    Block.sync();
    return 0;
  }

  @:qdFunc
  public static function storeTile16x16F32Batched(tile:Tensor<F32>, target:Tensor<F32>, batch:Int, base:Int, batchStride:Int, stride:Int):Int {
    var lane:Int = Block.threadIdx();
    if (lane < 256) {
      var row:Int = lane >> 4;
      var column:Int = lane & 15;
      target.kernelWrite(base + batch * batchStride + row * stride + column, tile.kernelRead(lane));
    }
    Block.sync();
    return 0;
  }
}
