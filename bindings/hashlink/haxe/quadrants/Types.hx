package quadrants;

enum abstract Arch(Int) from Int to Int {
  var Cpu = 0;
  var Cuda = 1;
  var Vulkan = 2;
  var Metal = 3;
  var Amdgpu = 4;
}

typedef I8 = Int;
typedef I16 = Int;
typedef I32 = Int;
typedef I64 = haxe.Int64;
typedef U8 = Int;
typedef U16 = Int;
typedef U32 = UInt;
typedef U64 = haxe.Int64;
typedef F32 = hl.F32;
typedef F64 = Float;

enum abstract DType(Int) from Int to Int {
  var I8 = 0;
  var I16 = 1;
  var I32 = 2;
  var I64 = 3;
  var U8 = 4;
  var U16 = 5;
  var U32 = 6;
  var U64 = 7;
  var F32 = 8;
  var F64 = 9;
}
