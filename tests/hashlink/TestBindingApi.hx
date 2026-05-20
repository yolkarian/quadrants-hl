import haxe.Int64;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.F64;
import quadrants.Types.I64;

class TestBindingApi {
  static function expectEq(name:String, got:Dynamic, expected:Dynamic):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function expectFloat(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function expectInt64(name:String, got:Int64, expected:Int64):Void {
    if (Int64.compare(got, expected) != 0) {
      throw '${name}: ${Std.string(got)} != ${Std.string(expected)}';
    }
  }

  static function expectThrows(name:String, contains:String, f:Void->Void):Void {
    try {
      f();
    } catch (e:Dynamic) {
      var message = Std.string(e);
      if (message.indexOf(contains) < 0) {
        throw '${name}: expected error containing "${contains}", got "${message}"';
      }
      return;
    }
    throw '${name}: expected an error containing "${contains}"';
  }

  static function closeContext(ctx:Context):Void {
    if (ctx != null) {
      try {
        ctx.close();
      } catch (_:Dynamic) {
      }
    }
  }

  static function closeKernel(k:Kernel):Void {
    if (k != null) {
      try {
        k.close();
      } catch (_:Dynamic) {
      }
    }
  }

  static function testEnumIdsAndTensorMetadata():Void {
    expectEq("DType.I8", DType.I8, 0);
    expectEq("DType.I16", DType.I16, 1);
    expectEq("DType.I32", DType.I32, 2);
    expectEq("DType.I64", DType.I64, 3);
    expectEq("DType.U8", DType.U8, 4);
    expectEq("DType.U16", DType.U16, 5);
    expectEq("DType.U32", DType.U32, 6);
    expectEq("DType.U64", DType.U64, 7);
    expectEq("DType.F32", DType.F32, 8);
    expectEq("DType.F64", DType.F64, 9);

    expectThrows("invalid_arch", "Unsupported Quadrants HashLink arch id", function() {
      var bad = new Context(cast 99);
      bad.close();
    });

    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);
      expectThrows("empty_shape", "shape must have at least one dimension", function() {
        ctx.ndarrayI32([]);
      });
      expectThrows("zero_shape", "shape dimensions must be positive", function() {
        ctx.ndarrayI32([2, 0]);
      });
      expectThrows("invalid_dtype", "Unsupported Quadrants HashLink dtype id", function() {
        ctx.ndarray((cast 99 : DType), [1]);
      });

      var t = ctx.ndarrayI32([2, 3, 4]);
      expectEq("tensor_dtype", t.dtype, DType.I32);
      expectEq("tensor_shape_rank", t.shape.length, 3);
      expectEq("tensor_shape0", t.shape[0], 2);
      expectEq("tensor_shape1", t.shape[1], 3);
      expectEq("tensor_shape2", t.shape[2], 4);
      expectEq("flat_origin", t.flatIndex([0, 0, 0]), 0);
      expectEq("flat_last", t.flatIndex([1, 2, 3]), 23);
      expectThrows("flat_rank_mismatch", "rank mismatch", function() {
        t.flatIndex([1, 2]);
      });
      expectThrows("flat_out_of_bounds", "out of bounds", function() {
        t.flatIndex([2, 0, 0]);
      });
      ctx.close();
    } catch (e:Dynamic) {
      closeContext(ctx);
      throw e;
    }
  }

  static function testPrimitiveHostDTypes():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);

      var i8 = ctx.ndarrayI8([3]);
      i8.fillI8(-2);
      i8.writeI8(1, 7);
      expectEq("i8_fill", i8.readI8(2), -2);
      expectEq("i8_write", i8.readI8(1), 7);

      var i16 = ctx.ndarrayI16([3]);
      i16.fillI16(-1234);
      i16.writeI16(0, 2345);
      expectEq("i16_fill", i16.readI16(2), -1234);
      expectEq("i16_write", i16.readI16(0), 2345);

      var i32 = ctx.ndarrayI32([2, 2]);
      i32.fillI32(12);
      i32.writeI32At([1, 1], 34);
      expectEq("i32_fill", i32.readI32(0), 12);
      expectEq("i32_multi_index", i32.readI32(1, 1), 34);

      var i64Value = Int64.make(0, 123456789);
      var i64 = ctx.ndarrayI64([2]);
      i64.fillI64(i64Value);
      i64.writeI64(0, Int64.make(-1, -42));
      expectInt64("i64_fill", i64.readI64(1), i64Value);
      expectInt64("i64_write", i64.readI64(0), Int64.make(-1, -42));

      var u8 = ctx.ndarrayU8([2]);
      u8.fillU8(255);
      u8.writeU8(0, 128);
      expectEq("u8_fill", u8.readU8(1), 255);
      expectEq("u8_write", u8.readU8(0), 128);

      var u16 = ctx.ndarrayU16([2]);
      u16.fillU16(65535);
      u16.writeU16(0, 32768);
      expectEq("u16_fill", u16.readU16(1), 65535);
      expectEq("u16_write", u16.readU16(0), 32768);

      var u32Max = Int64.make(0, -1);
      var u32 = ctx.ndarrayU32([2]);
      u32.fillU32(u32Max);
      u32.writeU32(0, Int64.make(0, -2));
      expectInt64("u32_fill", u32.readU32(1), u32Max);
      expectInt64("u32_write", u32.readU32(0), Int64.make(0, -2));

      var u64Max = Int64.make(-1, -1);
      var u64 = ctx.ndarrayU64([2]);
      u64.fillU64(u64Max);
      u64.writeU64(0, Int64.make(0x12345678, -1));
      expectInt64("u64_fill", u64.readU64(1), u64Max);
      expectInt64("u64_write", u64.readU64(0), Int64.make(0x12345678, -1));

      var f32 = ctx.ndarrayF32([2, 2]);
      f32.fillF32(1.25);
      f32.writeF32At([1, 0], 2.5);
      expectFloat("f32_fill", f32.readF32(0, 1), 1.25);
      expectFloat("f32_multi_index", f32.readF32(1, 0), 2.5);
      var f32Bytes = new hl.Bytes(12);
      f32.readF32Bytes(f32Bytes, 1, 2, 4);
      expectFloat("f32_bytes_first", f32Bytes.getF32(4), 1.25);
      expectFloat("f32_bytes_second", f32Bytes.getF32(8), 2.5);

      var f64 = ctx.ndarrayF64([2]);
      f64.fillF64(3.5);
      f64.writeF64(0, -4.25);
      expectFloat("f64_fill", f64.readF64(1), 3.5);
      expectFloat("f64_write", f64.readF64(0), -4.25);

      ctx.sync();
      ctx.close();
    } catch (e:Dynamic) {
      closeContext(ctx);
      throw e;
    }
  }

  static function testPrimitiveBulkReadBytes():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);
      var bytes = new hl.Bytes(32);

      var i8 = ctx.ndarrayI8([2]);
      i8.writeI8(0, -2);
      i8.writeI8(1, 7);
      i8.readI8Bytes(bytes, 0, 2, 1);
      expectEq("i8_bytes_0", bytes.getUI8(1), 254);
      expectEq("i8_bytes_1", bytes.getUI8(2), 7);

      var i16 = ctx.ndarrayI16([1]);
      i16.writeI16(0, 0x1234);
      i16.readI16Bytes(bytes, 0, 1, 2);
      expectEq("i16_bytes", bytes.getUI16(2), 0x1234);

      var i32 = ctx.ndarrayI32([2]);
      i32.writeI32(0, 0x12345678);
      i32.writeI32(1, 0x23456789);
      i32.readI32Bytes(bytes, 1, 1, 0);
      expectEq("i32_bytes_typed", bytes.getI32(0), 0x23456789);
      i32.readBytes(bytes, 0, 1, 4);
      expectEq("i32_bytes_generic", bytes.getI32(4), 0x12345678);

      var i64Value = Int64.make(0x11223344, 0x55667788);
      var i64 = ctx.ndarrayI64([1]);
      i64.writeI64(0, i64Value);
      i64.readI64Bytes(bytes, 0, 1, 0);
      expectEq("i64_bytes_low", bytes.getI32(0), 0x55667788);
      expectEq("i64_bytes_high", bytes.getI32(4), 0x11223344);

      var u8 = ctx.ndarrayU8([1]);
      u8.writeU8(0, 255);
      u8.readU8Bytes(bytes, 0, 1, 0);
      expectEq("u8_bytes", bytes.getUI8(0), 255);

      var u16 = ctx.ndarrayU16([1]);
      u16.writeU16(0, 0xabcd);
      u16.readU16Bytes(bytes, 0, 1, 0);
      expectEq("u16_bytes", bytes.getUI16(0), 0xabcd);

      var u32 = ctx.ndarrayU32([1]);
      u32.writeU32(0, Int64.make(0, 0x12345678));
      u32.readU32Bytes(bytes, 0, 1, 0);
      expectEq("u32_bytes", bytes.getI32(0), 0x12345678);

      var u64Value = Int64.make(0x01020304, 0x05060708);
      var u64 = ctx.ndarrayU64([1]);
      u64.writeU64(0, u64Value);
      u64.readU64Bytes(bytes, 0, 1, 0);
      expectEq("u64_bytes_low", bytes.getI32(0), 0x05060708);
      expectEq("u64_bytes_high", bytes.getI32(4), 0x01020304);

      var f32 = ctx.ndarrayF32([2]);
      f32.writeF32(0, 1.25);
      f32.writeF32(1, -2.5);
      f32.readF32Bytes(bytes, 0, 2, 4);
      expectFloat("f32_bytes_0", bytes.getF32(4), 1.25);
      expectFloat("f32_bytes_1", bytes.getF32(8), -2.5);

      var f64 = ctx.ndarrayF64([1]);
      f64.writeF64(0, -4.25);
      f64.readF64Bytes(bytes, 0, 1, 0);
      expectFloat("f64_bytes", bytes.getF64(0), -4.25);

      ctx.close();
    } catch (e:Dynamic) {
      closeContext(ctx);
      throw e;
    }
  }

  static function testKernelMigrationSmoke():Void {
    var ctx:Context = null;
    var k:Kernel = null;
    try {
      ctx = new Context(Arch.Cpu);

      var a = ctx.ndarrayI32([10]);
      var b = ctx.ndarrayI32([10]);
      a.writeI32(0, 3);
      b.writeI32(0, 5);
      k = Kernel.build(ctx, macro (a, b) -> {
        a[0] += b[0];
      });
      k.launch(a, b);
      ctx.sync();
      expectEq("kernel_smoke", a.readI32(0), 8);
      k.close();
      k = null;

      var grid = ctx.ndarrayI32([2, 3]);
      for (i in 0...2) {
        for (j in 0...3) {
          grid.writeI32At([i, j], i * 10 + j);
        }
      }
      k = Kernel.build(ctx, macro (grid) -> {
        for (i in 0...2) {
          for (j in 0...3) {
            grid[i][j] = grid[i][j] + i + j;
          }
        }
      });
      k.launch(grid);
      ctx.sync();
      expectEq("kernel_2d_00", grid.readI32(0, 0), 0);
      expectEq("kernel_2d_12", grid.readI32(1, 2), 15);
      k.close();
      k = null;

      var out64:Tensor<I64> = ctx.ndarrayI64([1]);
      var value64 = Int64.make(0, 7654321);
      k = Kernel.build(ctx, macro (out64:Tensor<I64>, value:haxe.Int64) -> {
        out64[0] = value;
      });
      k.launch(out64, value64);
      ctx.sync();
      expectInt64("kernel_i64_scalar", out64.readI64(0), value64);
      k.close();
      k = null;

      var outF64:Tensor<F64> = ctx.ndarrayF64([1]);
      k = Kernel.build(ctx, macro (outF64:Tensor<F64>, scale:Float) -> {
        outF64[0] = scale + 0.25;
      });
      k.launch(outF64, 1.5);
      ctx.sync();
      expectFloat("kernel_f64_scalar", outF64.readF64(0), 1.75);
      k.close();
      k = null;

      ctx.close();
    } catch (e:Dynamic) {
      closeKernel(k);
      closeContext(ctx);
      throw e;
    }
  }

  static function testRuntimeValidation():Void {
    var ctx:Context = null;
    var k:Kernel = null;
    try {
      ctx = new Context(Arch.Cpu);

      var out = ctx.ndarrayI32([2]);
      var f = ctx.ndarrayF32([1]);
      expectThrows("dtype_mismatch_host", "dtype mismatch", function() {
        f.readI32(0);
      });
      expectThrows("flat_index_oob", "flat index is out of bounds", function() {
        out.readI32(2);
      });
      expectThrows("bytes_dtype_mismatch", "dtype mismatch", function() {
        f.readI32Bytes(new hl.Bytes(4), 0, 1);
      });
      expectThrows("bytes_range_oob", "range is out of bounds", function() {
        f.readF32Bytes(new hl.Bytes(4), 1, 1);
      });

      k = Kernel.build(ctx, macro (out, n) -> {
        for (i in 0...n) {
          out[i] = i;
        }
      });
      expectThrows("kernel_arg_count", "argument count mismatch", function() {
        k.launch(out);
      });
      expectThrows("kernel_arg_dtype", "dtype mismatch", function() {
        k.launch(f, 1);
      });
      var rank2 = ctx.ndarrayI32([1, 2]);
      expectThrows("kernel_arg_rank", "rank mismatch", function() {
        k.launch(rank2, 2);
      });
      k.close();
      expectThrows("closed_kernel", "kernel is closed", function() {
        k.launch(out, 2);
      });
      k = null;

      ctx.close();
      expectThrows("closed_context_sync", "context is closed", function() {
        ctx.sync();
      });
      expectThrows("closed_context_ndarray", "context is closed", function() {
        ctx.ndarrayI32([1]);
      });

      var reopened = new Context(Arch.Cpu);
      reopened.sync();
      reopened.close();
    } catch (e:Dynamic) {
      closeKernel(k);
      closeContext(ctx);
      throw e;
    }
  }

  public static function run():Void {
    testEnumIdsAndTensorMetadata();
    testPrimitiveHostDTypes();
    testPrimitiveBulkReadBytes();
    testKernelMigrationSmoke();
    testRuntimeValidation();
  }
}
