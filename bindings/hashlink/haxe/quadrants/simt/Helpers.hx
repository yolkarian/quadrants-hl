package quadrants.simt;

class Helpers {
  public static function classes():Array<Class<Dynamic>> {
    return [cast BlockReduce, cast BlockScan, cast SubgroupCompat, cast TileSort];
  }
}
