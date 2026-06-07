package quadrants.simt;

import quadrants.Block;
import quadrants.Shared;
import quadrants.Types.F32;

class BlockScan {
  @:qdFunc
  public static function inclusiveAddI32(value:Int, width:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 256) {
      var addend:Int = 0;
      if (lane < limit && lane >= offset) {
        addend = (scratch.kernelRead(lane - offset) : Int);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : Int) + addend);
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:Int = value;
    if (lane < limit) result = (scratch.kernelRead(lane) : Int);
    return result;
  }

  @:qdFunc
  public static function exclusiveAddI32(value:Int, width:Int):Int {
    var inclusive:Int = inclusiveAddI32(value, width);
    return inclusive - value;
  }

  @:qdFunc
  public static function inclusiveAddF32(value:F32, width:Int):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 256) {
      var addend:F32 = 0.0;
      if (lane < limit && lane >= offset) {
        addend = scratch.kernelRead(lane - offset);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : Float) + (addend : Float));
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:F32 = value;
    if (lane < limit) result = scratch.kernelRead(lane);
    return result;
  }

  @:qdFunc
  public static function exclusiveAddF32(value:F32, width:Int):F32 {
    var inclusive:F32 = inclusiveAddF32(value, width);
    return (inclusive : Float) - (value : Float);
  }

  @:qdFunc
  public static function inclusiveMinI32(value:Int, width:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 256) {
      var candidate:Int = value;
      if (lane < limit && lane >= offset) {
        candidate = (scratch.kernelRead(lane - offset) : Int);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:Int = (scratch.kernelRead(lane) : Int);
        if (candidate < current) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:Int = value;
    if (lane < limit) result = (scratch.kernelRead(lane) : Int);
    return result;
  }

  @:qdFunc
  public static function exclusiveMinI32(value:Int, width:Int, identity:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var offset:Int = 1;
    while (offset < 256) {
      var candidate:Int = value;
      if (lane < limit && lane >= offset) {
        candidate = (scratch.kernelRead(lane - offset) : Int);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:Int = (scratch.kernelRead(lane) : Int);
        if (candidate < current) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }
    var result:Int = identity;
    if (lane > 0 && lane < limit) result = (scratch.kernelRead(lane - 1) : Int);
    return result;
  }

  @:qdFunc
  public static function inclusiveMaxI32(value:Int, width:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 256) {
      var candidate:Int = value;
      if (lane < limit && lane >= offset) {
        candidate = (scratch.kernelRead(lane - offset) : Int);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:Int = (scratch.kernelRead(lane) : Int);
        if (candidate > current) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:Int = value;
    if (lane < limit) result = (scratch.kernelRead(lane) : Int);
    return result;
  }

  @:qdFunc
  public static function exclusiveMaxI32(value:Int, width:Int, identity:Int):Int {
    var scratch = Shared.arrayI32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var offset:Int = 1;
    while (offset < 256) {
      var candidate:Int = value;
      if (lane < limit && lane >= offset) {
        candidate = (scratch.kernelRead(lane - offset) : Int);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:Int = (scratch.kernelRead(lane) : Int);
        if (candidate > current) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }
    var result:Int = identity;
    if (lane > 0 && lane < limit) result = (scratch.kernelRead(lane - 1) : Int);
    return result;
  }

  @:qdFunc
  public static function inclusiveMinF32(value:F32, width:Int):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 256) {
      var candidate:F32 = value;
      if (lane < limit && lane >= offset) {
        candidate = scratch.kernelRead(lane - offset);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:F32 = scratch.kernelRead(lane);
        if ((candidate : Float) < (current : Float)) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:F32 = value;
    if (lane < limit) result = scratch.kernelRead(lane);
    return result;
  }

  @:qdFunc
  public static function exclusiveMinF32(value:F32, width:Int, identity:F32):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var offset:Int = 1;
    while (offset < 256) {
      var candidate:F32 = value;
      if (lane < limit && lane >= offset) {
        candidate = scratch.kernelRead(lane - offset);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:F32 = scratch.kernelRead(lane);
        if ((candidate : Float) < (current : Float)) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }
    var result:F32 = identity;
    if (lane > 0 && lane < limit) result = scratch.kernelRead(lane - 1);
    return result;
  }

  @:qdFunc
  public static function inclusiveMaxF32(value:F32, width:Int):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 256) {
      var candidate:F32 = value;
      if (lane < limit && lane >= offset) {
        candidate = scratch.kernelRead(lane - offset);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:F32 = scratch.kernelRead(lane);
        if ((candidate : Float) > (current : Float)) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:F32 = value;
    if (lane < limit) result = scratch.kernelRead(lane);
    return result;
  }

  @:qdFunc
  public static function exclusiveMaxF32(value:F32, width:Int, identity:F32):F32 {
    var scratch = Shared.arrayF32(256);
    var lane:Int = Block.threadIdx();
    var limit:Int = blockScanClampWidth(width, 256);
    if (lane < limit) scratch.kernelWrite(lane, value);
    Block.sync();
    var offset:Int = 1;
    while (offset < 256) {
      var candidate:F32 = value;
      if (lane < limit && lane >= offset) {
        candidate = scratch.kernelRead(lane - offset);
      }
      Block.sync();
      if (lane < limit && lane >= offset) {
        var current:F32 = scratch.kernelRead(lane);
        if ((candidate : Float) > (current : Float)) scratch.kernelWrite(lane, candidate);
      }
      Block.sync();
      offset = offset << 1;
    }
    var result:F32 = identity;
    if (lane > 0 && lane < limit) result = scratch.kernelRead(lane - 1);
    return result;
  }

  @:qdFunc
  public static function inclusiveAddI32Tile16(value:Int):Int {
    var scratch = Shared.tile16I32();
    var lane:Int = Block.threadIdx();
    if (lane < 16) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 16) {
      var addend:Int = 0;
      if (lane < 16 && lane >= offset) {
        addend = (scratch.kernelRead(lane - offset) : Int);
      }
      Block.sync();
      if (lane < 16 && lane >= offset) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : Int) + addend);
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:Int = value;
    if (lane < 16) result = (scratch.kernelRead(lane) : Int);
    return result;
  }

  @:qdFunc
  public static function exclusiveAddI32Tile16(value:Int):Int {
    var inclusive:Int = inclusiveAddI32Tile16(value);
    return inclusive - value;
  }

  @:qdFunc
  public static function inclusiveAddF32Tile16(value:F32):F32 {
    var scratch = Shared.tile16F32();
    var lane:Int = Block.threadIdx();
    if (lane < 16) scratch.kernelWrite(lane, value);
    Block.sync();

    var offset:Int = 1;
    while (offset < 16) {
      var addend:F32 = 0.0;
      if (lane < 16 && lane >= offset) {
        addend = scratch.kernelRead(lane - offset);
      }
      Block.sync();
      if (lane < 16 && lane >= offset) {
        scratch.kernelWrite(lane, (scratch.kernelRead(lane) : Float) + (addend : Float));
      }
      Block.sync();
      offset = offset << 1;
    }

    var result:F32 = value;
    if (lane < 16) result = scratch.kernelRead(lane);
    return result;
  }

  @:qdFunc
  public static function exclusiveAddF32Tile16(value:F32):F32 {
    var inclusive:F32 = inclusiveAddF32Tile16(value);
    return (inclusive : Float) - (value : Float);
  }

  @:qdFunc
  public static function blockScanClampWidth(width:Int, maxWidth:Int):Int {
    var limit = width;
    if (limit > maxWidth) limit = maxWidth;
    if (limit < 1) limit = 1;
    return limit;
  }
}
