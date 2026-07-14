package quadrants.simt;

class Helpers {
  public static function classes():Array<Class<Dynamic>> {
    return [
      cast BlockReduce,
      cast BlockScan,
      cast SubgroupCompat,
      cast SubgroupScan,
      cast SubgroupSegmented,
      cast SubgroupVote,
      cast SubgroupBitonicSort,
      cast TileSort,
      cast Tile16x16F32,
      cast Tile16x16F32Ops,
      cast Tile16x16F64,
      cast Tile16x16F64Ops,
      cast Tile32x32F32,
      cast Tile32x32F32Ops,
      cast Tile32x32F64,
      cast Tile32x32F64Ops,
    ];
  }
}
