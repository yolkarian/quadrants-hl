package quadrants.simt;

import quadrants.Block;
import quadrants.Shared;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U64;

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
  public static function reduceAddU32(value:U32, width:Int):U32 {
    var scratch = Shared.arrayU32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : haxe.Int64) + (scratch.kernelRead(lane + stride) : haxe.Int64));
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMinU32(value:U32, width:Int):U32 {
    var scratch = Shared.arrayU32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:U32 = scratch.kernelRead(lane);
        var other:U32 = scratch.kernelRead(lane + stride);
        if ((other : haxe.Int64) < (current : haxe.Int64)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMaxU32(value:U32, width:Int):U32 {
    var scratch = Shared.arrayU32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:U32 = scratch.kernelRead(lane);
        var other:U32 = scratch.kernelRead(lane + stride);
        if ((other : haxe.Int64) > (current : haxe.Int64)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceAddI64(value:I64, width:Int):I64 {
    var scratch = Shared.arrayI64(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : haxe.Int64) + (scratch.kernelRead(lane + stride) : haxe.Int64));
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMinI64(value:I64, width:Int):I64 {
    var scratch = Shared.arrayI64(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:I64 = scratch.kernelRead(lane);
        var other:I64 = scratch.kernelRead(lane + stride);
        if ((other : haxe.Int64) < (current : haxe.Int64)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMaxI64(value:I64, width:Int):I64 {
    var scratch = Shared.arrayI64(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:I64 = scratch.kernelRead(lane);
        var other:I64 = scratch.kernelRead(lane + stride);
        if ((other : haxe.Int64) > (current : haxe.Int64)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceAddU64(value:U64, width:Int):U64 {
    var scratch = Shared.arrayU64(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : haxe.Int64) + (scratch.kernelRead(lane + stride) : haxe.Int64));
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
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
  public static function reduceAddF64(value:F64, width:Int):F64 {
    var scratch = Shared.arrayF64(256);
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
  public static function reduceMinF64(value:F64, width:Int):F64 {
    var scratch = Shared.arrayF64(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:F64 = scratch.kernelRead(lane);
        var other:F64 = scratch.kernelRead(lane + stride);
        if ((other : Float) < (current : Float)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceMaxF64(value:F64, width:Int):F64 {
    var scratch = Shared.arrayF64(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockReduceClampedWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var stride:Int = 128;
    while (stride > 0) {
      if (lane < stride && lane + stride < limit) {
        var current:F64 = scratch.kernelRead(lane);
        var other:F64 = scratch.kernelRead(lane + stride);
        if ((other : Float) > (current : Float)) scratch.kernelWrite(lane, other);
      }
      Block.sync();
      stride = stride >> 1;
    }
    return scratch.kernelRead(0);
  }

  @:qdFunc
  public static function reduceAllI32(value:Int):Int {
    return Block.barrierAnd(value);
  }

  @:qdFunc
  public static function reduceAnyI32(value:Int):Int {
    return Block.barrierOr(value);
  }

  @:qdFunc
  public static function reduceCountI32(value:Int):Int {
    return Block.barrierCount(value);
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
  public static function reduceAddF32Tile16(value:F32):F32 {
    return reduceAddF32(value, 16);
  }

  @:qdFunc
  public static function reduceMinF32Tile16(value:F32):F32 {
    return reduceMinF32(value, 16);
  }

  @:qdFunc
  public static function reduceMaxF32Tile16(value:F32):F32 {
    return reduceMaxF32(value, 16);
  }

  @:qdFunc
  public static function blockReduceClampedWidth(width:Int, maxWidth:Int):Int {
    var limit = width;
    if (limit > maxWidth) limit = maxWidth;
    if (limit < 1) limit = 1;
    return limit;
  }
}
