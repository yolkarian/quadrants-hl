package quadrants;

abstract QContext(hl.Abstract<"qd_context">) {}
abstract QKernel(hl.Abstract<"qd_kernel">) {}
abstract QNdarray(hl.Abstract<"qd_ndarray">) {}

class Native {
  @:hlNative("quadrants", "context_create")
  public static function context_create(arch:Int):QContext {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_sync")
  public static function context_sync(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_close")
  public static function context_close(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_create")
  public static function ndarray_create(ctx:QContext, dtype:Int, shape:hl.NativeArray<Int>):QNdarray {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i8")
  public static function ndarray_fill_i8(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i8")
  public static function ndarray_read_i8(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i8")
  public static function ndarray_write_i8(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i16")
  public static function ndarray_fill_i16(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i16")
  public static function ndarray_read_i16(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i16")
  public static function ndarray_write_i16(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i32")
  public static function ndarray_fill_i32(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i32")
  public static function ndarray_read_i32(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i32")
  public static function ndarray_write_i32(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i64")
  public static function ndarray_fill_i64(ctx:QContext, arr:QNdarray, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i64")
  public static function ndarray_read_i64(ctx:QContext, arr:QNdarray, flatIndex:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i64")
  public static function ndarray_write_i64(ctx:QContext, arr:QNdarray, flatIndex:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u8")
  public static function ndarray_fill_u8(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u8")
  public static function ndarray_read_u8(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u8")
  public static function ndarray_write_u8(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u16")
  public static function ndarray_fill_u16(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u16")
  public static function ndarray_read_u16(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u16")
  public static function ndarray_write_u16(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u32")
  public static function ndarray_fill_u32(ctx:QContext, arr:QNdarray, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u32")
  public static function ndarray_read_u32(ctx:QContext, arr:QNdarray, flatIndex:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u32")
  public static function ndarray_write_u32(ctx:QContext, arr:QNdarray, flatIndex:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u64")
  public static function ndarray_fill_u64(ctx:QContext, arr:QNdarray, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u64")
  public static function ndarray_read_u64(ctx:QContext, arr:QNdarray, flatIndex:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u64")
  public static function ndarray_write_u64(ctx:QContext, arr:QNdarray, flatIndex:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_f32")
  public static function ndarray_fill_f32(ctx:QContext, arr:QNdarray, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_f32")
  public static function ndarray_read_f32(ctx:QContext, arr:QNdarray, flatIndex:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_f32")
  public static function ndarray_write_f32(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_f64")
  public static function ndarray_fill_f64(ctx:QContext, arr:QNdarray, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_f64")
  public static function ndarray_read_f64(ctx:QContext, arr:QNdarray, flatIndex:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_f64")
  public static function ndarray_write_f64(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_compile")
  public static function kernel_compile(ctx:QContext, descriptor:hl.Bytes, length:Int):QKernel {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch")
  public static function kernel_launch(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_close")
  public static function kernel_close(kernel:QKernel):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }
}
