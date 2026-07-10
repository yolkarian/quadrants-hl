package quadrants.tools;

import haxe.Int64;

/**
  Statically typed scalar buffers accepted by `VtkWriter`.

  `UInt32` uses `Int64` so values up to 4,294,967,295 remain representable on
  HashLink, whose `Int` is signed 32-bit.
*/
enum VtkScalarData {
  Int8(values:Array<Int>);
  UInt8(values:Array<Int>);
  Int16(values:Array<Int>);
  UInt16(values:Array<Int>);
  Int32(values:Array<Int>);
  UInt32(values:Array<Int64>);
  Float32(values:Array<Float>);
  Float64(values:Array<Float>);
}
