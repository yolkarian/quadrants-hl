package quadrants.simt;

class Helpers {
  public static function classes():Array<Class<Dynamic>> {
    return [
      cast BlockReduce,
      cast BlockScan,
      cast SubgroupCompat,
      cast TileSort,
      cast Tile16x16F32,
      cast Tile16x16F64,
      cast Tile32x32F32,
      cast Tile32x32F64,
    ];
  }
}
