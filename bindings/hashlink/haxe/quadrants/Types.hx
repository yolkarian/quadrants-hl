package quadrants;

enum abstract Arch(Int) from Int to Int {
  var Cpu = 0;
  var Cuda = 1;
  var Vulkan = 2;
  var Metal = 3;
  var Amdgpu = 4;
}

abstract I8(Int) from Int to Int {}
abstract I16(Int) from Int to Int {}
abstract I32(Int) from Int to Int {
  @:op(A + B) static inline function add(a:I32, b:I32):I32 return (a : Int) + (b : Int);
  @:op(A - B) static inline function sub(a:I32, b:I32):I32 return (a : Int) - (b : Int);
  @:op(A * B) static inline function mul(a:I32, b:I32):I32 return (a : Int) * (b : Int);
  @:op(A / B) static inline function div(a:I32, b:I32):I32 return Std.int((a : Int) / (b : Int));
  @:op(A % B) static inline function mod(a:I32, b:I32):I32 return (a : Int) % (b : Int);
  @:op(A > B) static inline function gt(a:I32, b:I32):Bool return (a : Int) > (b : Int);
  @:op(A >= B) static inline function gte(a:I32, b:I32):Bool return (a : Int) >= (b : Int);
  @:op(A < B) static inline function lt(a:I32, b:I32):Bool return (a : Int) < (b : Int);
  @:op(A <= B) static inline function lte(a:I32, b:I32):Bool return (a : Int) <= (b : Int);
}
abstract I64(haxe.Int64) from haxe.Int64 to haxe.Int64 {}
abstract U8(Int) from Int to Int {}
abstract U16(Int) from Int to Int {}
abstract U32(haxe.Int64) from haxe.Int64 to haxe.Int64 {}
abstract U64(haxe.Int64) from haxe.Int64 to haxe.Int64 {}
abstract U1(Bool) from Bool to Bool {}
abstract F16(Float) from Float to Float {}
abstract F32(hl.F32) from hl.F32 to hl.F32 {
  @:from public static inline function fromFloat(value:Float):F32 return cast value;
  @:to public inline function toFloat():Float return cast this;
}
abstract F64(Float) from Float to Float {}

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
  var U1 = 10;
  var F16 = 11;
}

enum abstract AutodiffMode(Int) from Int to Int {
  var None = 0;
  var Forward = 1;
  var Reverse = 2;
  var Validate = 3;
}
