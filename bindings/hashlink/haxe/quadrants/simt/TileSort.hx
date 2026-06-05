package quadrants.simt;

import quadrants.Block;
import quadrants.Shared;
import quadrants.Types.I32;

class TileSort {
  @:qdFunc
  public static function sortAscendingI32Tile16(value:Int):Int {
    var tile = Shared.tile16I32();
    var lane:Int = Block.threadIdx();
    if (lane < 16) tile.kernelWrite(lane, value);
    Block.sync();

    var span:Int = 2;
    while (span <= 16) {
      var stride:Int = span >> 1;
      while (stride > 0) {
        if (lane < 16) {
          var pair:Int = lane ^ stride;
          if (pair > lane && pair < 16) {
            var a:Int = (tile.kernelRead(lane) : Int);
            var b:Int = (tile.kernelRead(pair) : Int);
            var ascending:Bool = (lane & span) == 0;
            if ((ascending && a > b) || (!ascending && a < b)) {
              tile.kernelWrite(lane, b);
              tile.kernelWrite(pair, a);
            }
          }
        }
        Block.sync();
        stride = stride >> 1;
      }
      span = span << 1;
    }

    var result:Int = value;
    if (lane < 16) result = (tile.kernelRead(lane) : Int);
    return result;
  }

  @:qdFunc
  public static function sortDescendingI32Tile16(value:Int):Int {
    var tile = Shared.tile16I32();
    var lane:Int = Block.threadIdx();
    if (lane < 16) tile.kernelWrite(lane, value);
    Block.sync();

    var span:Int = 2;
    while (span <= 16) {
      var stride:Int = span >> 1;
      while (stride > 0) {
        if (lane < 16) {
          var pair:Int = lane ^ stride;
          if (pair > lane && pair < 16) {
            var a:Int = (tile.kernelRead(lane) : Int);
            var b:Int = (tile.kernelRead(pair) : Int);
            var ascending:Bool = (lane & span) != 0;
            if ((ascending && a > b) || (!ascending && a < b)) {
              tile.kernelWrite(lane, b);
              tile.kernelWrite(pair, a);
            }
          }
        }
        Block.sync();
        stride = stride >> 1;
      }
      span = span << 1;
    }

    var result:Int = value;
    if (lane < 16) result = (tile.kernelRead(lane) : Int);
    return result;
  }
}
