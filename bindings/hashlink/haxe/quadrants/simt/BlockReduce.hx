package quadrants.simt;

import quadrants.Block;
import quadrants.Shared;
import quadrants.Types.F32;
import quadrants.Types.I32;

class BlockReduce {
  @:qdFunc
  public static function reduceAddI32(value:Int, width:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : Int) + (scratch.kernelRead(lane + stride) : Int));
      }
      Block.sync();
      stride = stride >> 1;
    }
    return (scratch.kernelRead(0) : Int);
  }

  @:qdFunc
  public static function reduceMinI32(value:Int, width:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:Int = (scratch.kernelRead(lane) : Int);
        var other:Int = (scratch.kernelRead(lane + stride) : Int);
        if (other < current) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return (scratch.kernelRead(0) : Int);
  }

  @:qdFunc
  public static function reduceMaxI32(value:Int, width:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:Int = (scratch.kernelRead(lane) : Int);
        var other:Int = (scratch.kernelRead(lane + stride) : Int);
        if (other > current) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return (scratch.kernelRead(0) : Int);
  }

  @:qdFunc
  public static function reduceAddF32(value:F32, width:Int):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : Float) + (scratch.kernelRead(lane + stride) : Float));
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMinF32(value:F32, width:Int):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:F32 = scratch.kernelRead(lane);
        var other:F32 = scratch.kernelRead(lane + stride);
        if ((other : Float) < (current : Float)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMaxF32(value:F32, width:Int):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:F32 = scratch.kernelRead(lane);
        var other:F32 = scratch.kernelRead(lane + stride);
        if ((other : Float) > (current : Float)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceAddI32Tile16(value:Int):Int {
    return reduceAddI32(value, 16);
  }

  @:qdFunc
  public static function reduceMinI32Tile16(value:Int):Int {
    return reduceMinI32(value, 16);
  }

  @:qdFunc
  public static function reduceMaxI32Tile16(value:Int):Int {
    return reduceMaxI32(value, 16);
  }

  @:qdFunc
  public static function blockReduceClampedWidth(width:Int, maxWidth:Int):Int {
    var limit = width;
    if (limit > maxWidth) limit = maxWidth;
    if (limit < 1) limit = 1;
    return limit;
  }
}
