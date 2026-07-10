package quadrants.tools;

import haxe.Int64;

/**
  Statically typed scalar buffers accepted by `PlyWriter` properties.

  `UInt32` uses `Int64` so every value in the PLY `uint` range is
  representable without relying on signed `Int` bit patterns.
*/
enum PlyScalarData {
  Int8(values:Array<Int>);
  UInt8(values:Array<Int>);
  Int16(values:Array<Int>);
  UInt16(values:Array<Int>);
  Int32(values:Array<Int>);
  UInt32(values:Array<Int64>);
  Float32(values:Array<Float>);
  Float64(values:Array<Float>);
}
