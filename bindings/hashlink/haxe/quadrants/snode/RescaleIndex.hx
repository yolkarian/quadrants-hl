package quadrants.snode;

/**
 * Rescales a grouped loop index between two field shapes related by integer factors,
 * mirroring the Python binding's `rescale_index(a, b, I)` semantics: component `i`
 * is divided by `fromShape[i] / toShape[i]` when the source shape is larger and
 * multiplied by `toShape[i] / fromShape[i]` when the target shape is larger.
 *
 * Inside kernels the same arithmetic is written directly with literal factors,
 * for example `coarse[i >> 1]` or `fine[i * 2]` for a factor-2 relation.
 */
class RescaleIndex {
  public static function map(fromShape:Array<Int>, toShape:Array<Int>, index:Array<Int>):Array<Int> {
    if (fromShape == null || toShape == null || index == null) {
      throw "Quadrants rescaleIndex requires source shape, target shape, and index arrays";
    }
    var rank = index.length;
    if (rank == 0) {
      throw "Quadrants rescaleIndex requires a non-empty index";
    }
    if (fromShape.length != rank || toShape.length != rank) {
      throw 'Quadrants rescaleIndex requires matching ranks (fromShape=${fromShape.length}, toShape=${toShape.length}, index=${rank})';
    }
    var result = [for (value in index) value];
    var axes = rank;
    for (i in 0...axes) {
      if (fromShape[i] <= 0 || toShape[i] <= 0) {
        throw "Quadrants rescaleIndex requires positive shape extents";
      }
      if (fromShape[i] > toShape[i]) {
        if (fromShape[i] % toShape[i] != 0) {
          throw 'Quadrants rescaleIndex requires shapes with integer ratios (axis ${i}: ${fromShape[i]} vs ${toShape[i]})';
        }
        var factor = Std.int(fromShape[i] / toShape[i]);
        result[i] = Std.int(Math.floor(index[i] / factor));
      } else if (fromShape[i] < toShape[i]) {
        if (toShape[i] % fromShape[i] != 0) {
          throw 'Quadrants rescaleIndex requires shapes with integer ratios (axis ${i}: ${fromShape[i]} vs ${toShape[i]})';
        }
        result[i] = index[i] * Std.int(toShape[i] / fromShape[i]);
      }
    }
    return result;
  }
}
