import haxe.Int64;
import quadrants.Context;
import quadrants.DLPackTensor;
import quadrants.Kernel;
import quadrants.Mesh;
import quadrants.Mesh.MeshElementType;
import quadrants.SparseMatrix;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Tensor;
import quadrants.Types.I8;
import quadrants.Types.I16;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U8;
import quadrants.Types.U16;
import quadrants.Types.U32;
import quadrants.Types.U64;
import quadrants.Types.U1;
import quadrants.Types.F16;
import quadrants.Types.F32;
import quadrants.Types.F64;

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

  static function testProfilerContextOption():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu, true);
      var profiler = ctx.profiler();
      profiler.start("manual");
      profiler.stop();
      var manualRecord = profiler.record("manual");
      expectEq("profiler_record_count_type", manualRecord.count >= 0, true);
      profiler.clear();
      ctx.setAdstackConfig(true, 4096, 0);
      ctx.setRandomSeed(12345);
      ctx.setCpuMaxNumThreads(1);
      ctx.setFastMath(true);
      ctx.setBoundsCheck(true);
      ctx.setDebugDump("/tmp/quadrants-hashlink-ir", false, false, true);
      ctx.close();
    } catch (e:Dynamic) {
      closeContext(ctx);
      throw e;
    }
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
    expectEq("DType.U1", DType.U1, 10);
    expectEq("DType.F16", DType.F16, 11);

    expectThrows("invalid_arch", "Unsupported Quadrants HashLink arch id", function() {
      var bad = new Context(cast 99);
      bad.close();
    });

    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);
      expectThrows("empty_shape", "shape must have at least one dimension", function() {
        new Tensor<I32>(ctx, []);
      });
      expectThrows("zero_shape", "shape dimensions must be positive", function() {
        new Tensor<I32>(ctx, [2, 0]);
      });
      var t = new Tensor<I32>(ctx, [2, 3, 4]);
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

      var i8 = new Tensor<I8>(ctx, [3]);
      i8.fill(-2);
      i8.write(1, 7);
      expectEq("i8_fill", i8.read(2), -2);
      expectEq("i8_write", i8.read(1), 7);
      i8.fromArray([1, 2, 3]);
      expectEq("i8_to_array", i8.toArray()[2], 3);

      var i16 = new Tensor<I16>(ctx, [3]);
      i16.fill(-1234);
      i16.write(0, 2345);
      expectEq("i16_fill", i16.read(2), -1234);
      expectEq("i16_write", i16.read(0), 2345);

      var i32 = new Tensor<I32>(ctx, [2, 2]);
      i32.fill(12);
      i32.writeAt([1, 1], 34);
      expectEq("i32_fill", i32.read(0), 12);
      expectEq("i32_multi_index", i32.readAt([1, 1]), 34);
      i32.fromArray([1, 2, 3, 4]);
      var i32Host = i32.toArray();
      expectEq("i32_to_array_0", i32Host[0], 1);
      expectEq("i32_to_array_3", i32Host[3], 4);

      var i64Value = Int64.make(0, 123456789);
      var i64 = new Tensor<I64>(ctx, [2]);
      i64.fill(i64Value);
      i64.write(0, Int64.make(-1, -42));
      expectInt64("i64_fill", i64.read(1), i64Value);
      expectInt64("i64_write", i64.read(0), Int64.make(-1, -42));
      i64.fromArray([Int64.make(0, 1), Int64.make(0, 2)]);
      expectInt64("i64_to_array", i64.toArray()[1], Int64.make(0, 2));

      var u8 = new Tensor<U8>(ctx, [2]);
      u8.fill(255);
      u8.write(0, 128);
      expectEq("u8_fill", u8.read(1), 255);
      expectEq("u8_write", u8.read(0), 128);
      u8.fromArray([4, 5]);
      expectEq("u8_to_array", u8.toArray()[1], 5);

      var u16 = new Tensor<U16>(ctx, [2]);
      u16.fill(65535);
      u16.write(0, 32768);
      expectEq("u16_fill", u16.read(1), 65535);
      expectEq("u16_write", u16.read(0), 32768);

      var u32Max = Int64.make(0, -1);
      var u32 = new Tensor<U32>(ctx, [2]);
      u32.fill(u32Max);
      u32.write(0, Int64.make(0, -2));
      expectInt64("u32_fill", u32.read(1), u32Max);
      expectInt64("u32_write", u32.read(0), Int64.make(0, -2));
      u32.fromArray([Int64.make(0, 3), Int64.make(0, 4)]);
      expectInt64("u32_to_array", u32.toArray()[1], Int64.make(0, 4));

      var u64Max = Int64.make(-1, -1);
      var u64 = new Tensor<U64>(ctx, [2]);
      u64.fill(u64Max);
      u64.write(0, Int64.make(0x12345678, -1));
      expectInt64("u64_fill", u64.read(1), u64Max);
      expectInt64("u64_write", u64.read(0), Int64.make(0x12345678, -1));

      var u1 = new Tensor<U1>(ctx, [3]);
      u1.fill(true);
      u1.write(1, false);
      expectEq("u1_fill", u1.read(0), true);
      expectEq("u1_write", u1.read(1), false);
      u1.fromArray([false, true, false]);
      expectEq("u1_to_array", u1.toArray()[1], true);



      var f16 = new Tensor<F16>(ctx, [2]);
      f16.fill(1.5);
      f16.write(0, -2.25);
      expectFloat("f16_fill", f16.read(1), 1.5);
      expectFloat("f16_write", f16.read(0), -2.25);
      f16.fromArray([3.5, 4.5]);
      expectFloat("f16_to_array", f16.toArray()[1], 4.5);

      var f32 = new Tensor<F32>(ctx, [2, 2]);
      f32.fill(1.25);
      f32.writeAt([1, 0], 2.5);
      expectFloat("f32_fill", f32.readAt([0, 1]), 1.25);
      expectFloat("f32_multi_index", f32.readAt([1, 0]), 2.5);
      f32.fromArray([1.0, 2.0, 3.0, 4.0]);
      var f32Host = f32.toArray();
      expectFloat("f32_to_array_0", f32Host[0], 1.0);
      expectFloat("f32_to_array_3", f32Host[3], 4.0);
      var f32Bytes = new hl.Bytes(12);
      f32.readBytes(f32Bytes, 1, 2, 4);
      expectFloat("f32_bytes_first", f32Bytes.getF32(4), 2.0);
      expectFloat("f32_bytes_second", f32Bytes.getF32(8), 3.0);

      var f64 = new Tensor<F64>(ctx, [2]);
      f64.fill(3.5);
      f64.write(0, -4.25);
      expectFloat("f64_fill", f64.read(1), 3.5);
      expectFloat("f64_write", f64.read(0), -4.25);
      f64.fromArray([6.5, 7.5]);
      expectFloat("f64_to_array", f64.toArray()[1], 7.5);

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

      var i8 = new Tensor<I8>(ctx, [2]);
      i8.write(0, -2);
      i8.write(1, 7);
      i8.readBytes(bytes, 0, 2, 1);
      expectEq("i8_bytes_0", bytes.getUI8(1), 254);
      expectEq("i8_bytes_1", bytes.getUI8(2), 7);

      var i16 = new Tensor<I16>(ctx, [1]);
      i16.write(0, 0x1234);
      i16.readBytes(bytes, 0, 1, 2);
      expectEq("i16_bytes", bytes.getUI16(2), 0x1234);

      var i32 = new Tensor<I32>(ctx, [2]);
      i32.write(0, 0x12345678);
      i32.write(1, 0x23456789);
      i32.readBytes(bytes, 1, 1, 0);
      expectEq("i32_bytes_typed", bytes.getI32(0), 0x23456789);
      i32.readBytes(bytes, 0, 1, 4);
      expectEq("i32_bytes_generic", bytes.getI32(4), 0x12345678);
      bytes.setI32(8, 0x3456789a);
      i32.writeBytes(bytes, 0, 1, 8);
      expectEq("i32_write_bytes", i32.read(0), 0x3456789a);
      var copyBytes = new hl.Bytes(8);
      i32.copyToBytes(copyBytes);
      expectEq("i32_copy_to_bytes", copyBytes.getI32(0), 0x3456789a);
      copyBytes.setI32(0, 0x456789ab);
      i32.copyFromBytes(copyBytes, 1, 1);
      expectEq("i32_copy_from_bytes", i32.read(1), 0x456789ab);
      i32.enableGrad();
      var typedGrad:Tensor<I32> = i32.grad;
      var typedDual:Tensor<I32> = i32.dual;
      typedGrad.write(0, 12);
      typedDual.write(0, 13);
      expectEq("tensor_needs_grad", i32.needsGrad, true);
      expectEq("tensor_grad_storage", i32.grad.read(0), 12);
      expectEq("tensor_dual_storage", i32.dual.read(0), 13);
      expectEq("tensor_zero_copy_probe", i32.supportsZeroCopy(), true);
      expectEq("tensor_external_pointer_probe", i32.supportsExternalPointerImport(), true);
      expectEq("tensor_dlpack_probe", i32.supportsDLPack(), true);

      var i64Value = Int64.make(0x11223344, 0x55667788);
      var i64 = new Tensor<I64>(ctx, [1]);
      i64.write(0, i64Value);
      i64.readBytes(bytes, 0, 1, 0);
      expectEq("i64_bytes_low", bytes.getI32(0), 0x55667788);
      expectEq("i64_bytes_high", bytes.getI32(4), 0x11223344);

      var u8 = new Tensor<U8>(ctx, [1]);
      u8.write(0, 255);
      u8.readBytes(bytes, 0, 1, 0);
      expectEq("u8_bytes", bytes.getUI8(0), 255);

      var u16 = new Tensor<U16>(ctx, [1]);
      u16.write(0, 0xabcd);
      u16.readBytes(bytes, 0, 1, 0);
      expectEq("u16_bytes", bytes.getUI16(0), 0xabcd);

      var u32 = new Tensor<U32>(ctx, [1]);
      u32.write(0, Int64.make(0, 0x12345678));
      u32.readBytes(bytes, 0, 1, 0);
      expectEq("u32_bytes", bytes.getI32(0), 0x12345678);

      var u64Value = Int64.make(0x01020304, 0x05060708);
      var u64 = new Tensor<U64>(ctx, [1]);
      u64.write(0, u64Value);
      u64.readBytes(bytes, 0, 1, 0);
      expectEq("u64_bytes_low", bytes.getI32(0), 0x05060708);
      expectEq("u64_bytes_high", bytes.getI32(4), 0x01020304);

      var f32 = new Tensor<F32>(ctx, [2]);
      f32.write(0, 1.25);
      f32.write(1, -2.5);
      f32.readBytes(bytes, 0, 2, 4);
      expectFloat("f32_bytes_0", bytes.getF32(4), 1.25);
      expectFloat("f32_bytes_1", bytes.getF32(8), -2.5);

      var f64 = new Tensor<F64>(ctx, [1]);
      f64.write(0, -4.25);
      f64.readBytes(bytes, 0, 1, 0);
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

      var a = new Tensor<I32>(ctx, [10]);
      var b = new Tensor<I32>(ctx, [10]);
      a.write(0, 3);
      b.write(0, 5);
      k = Kernel.build(ctx, macro (a, b) -> {
        a[0] += b[0];
      });
      k.launch(a, b);
      ctx.sync();
      expectEq("kernel_smoke", a.read(0), 8);
      k.close();
      k = null;

      var grid = new Tensor<I32>(ctx, [2, 3]);
      for (i in 0...2) {
        for (j in 0...3) {
          grid.writeAt([i, j], i * 10 + j);
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
      expectEq("kernel_2d_00", grid.readAt([0, 0]), 0);
      expectEq("kernel_2d_12", grid.readAt([1, 2]), 15);
      k.close();
      k = null;

      var out64:Tensor<I64> = new Tensor<I64>(ctx, [1]);
      var value64 = Int64.make(0, 7654321);
      k = Kernel.build(ctx, macro (out64:Tensor<I64>, value:haxe.Int64) -> {
        out64[0] = value;
      });
      k.launch(out64, value64);
      ctx.sync();
      expectInt64("kernel_i64_scalar", out64.read(0), value64);
      k.close();
      k = null;

      var outF64:Tensor<F64> = new Tensor<F64>(ctx, [1]);
      k = Kernel.build(ctx, macro (outF64:Tensor<F64>, scale:Float) -> {
        outF64[0] = scale + 0.25;
      });
      k.launch(outF64, 1.5);
      ctx.sync();
      expectFloat("kernel_f64_scalar", outF64.read(0), 1.75);
      k.close();
      k = null;
      var source = new Tensor<I32>(ctx, [4]);
      source.fromArray([10, 20, 30, 40]);
      var view = source.view(1, 2);
      var outView = new Tensor<I32>(ctx, [1]);
      k = Kernel.build(ctx, macro (view:quadrants.BufferView<I32>, out:Tensor<I32>) -> {
        out[0] = view[1] + view.shape(0);
      });
      k.launch(view, outView);
      ctx.sync();
      expectEq("kernel_buffer_view_flatten", outView.read(0), 32);
      k.close();
      k = null;


      ctx.close();
    } catch (e:Dynamic) {
      closeKernel(k);
      closeContext(ctx);
      throw e;
    }
  }

  static function testHostConvenienceContainers():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);
      var tensor = new Tensor<I32>(ctx, [4]);
      tensor.fromArray([1, 2, 3, 4]);
      var view = tensor.view(1, 2);
      expectEq("buffer_view_read", view.read(0), 2);
      expectEq("buffer_view_shape", view.shape(0), 2);
      view.write(1, 9);
      expectEq("buffer_view_write", tensor.read(2), 9);
      expectThrows("buffer_view_oob", "out of bounds", function() {
        tensor.view(3, 2);
      });
      var half = new Tensor<F16>(ctx, [2, 2]);
      half.writeAt([1, 1], 1.5);
      expectFloat("tensor_f16_at", half.readAt([1, 1]), 1.5);
      var flag = new Tensor<U1>(ctx, [2, 2]);
      flag.writeAt([0, 1], true);
      if (!flag.readAt([0, 1])) throw "tensor_u1_at";


      var sparse = new SparseMatrix<Int>(3, 3);
      sparse.set(0, 1, 2);
      sparse.set(2, 0, 4);
      expectEq("sparse_get", sparse.get(2, 0, 0), 4);
      expectEq("sparse_nnz", sparse.nnz, 2);
      var product = sparse.matVec([10, 20, 30], 0);
      expectEq("sparse_matvec0", product[0], 40);
      expectEq("sparse_matvec2", product[2], 40);
      var transposed = sparse.transpose();
      expectEq("sparse_transpose", transposed.get(1, 0, 0), 2);
      var doubled = sparse.add(sparse, 0);
      expectEq("sparse_add", doubled.get(0, 1, 0), 4);
      var scaled = sparse.scale(3);
      expectEq("sparse_scale", scaled.get(2, 0, 0), 12);

      var mesh = new Mesh(3, 2, 1);
      expectEq("mesh_vertices", mesh.count(MeshElementType.Vertex), 3);
      mesh.setRelation(MeshElementType.Vertex, 1, MeshElementType.Face, [0]);
      expectEq("mesh_relation_size", mesh.relationSize(MeshElementType.Vertex, 1, MeshElementType.Face), 1);
      expectEq("mesh_relation_access", mesh.relationAccess(MeshElementType.Vertex, 1, MeshElementType.Face, 0), 0);
      var vertexSum = 0;
      for (v in mesh.vertices()) {
        vertexSum += v;
      }
      expectEq("mesh_iter", vertexSum, 3);

      ctx.close();
    } catch (e:Dynamic) {
      closeContext(ctx);
      throw e;
    }
  }

  static function testRuntimeValidation():Void {
    var ctx:Context = null;
    var k:Kernel = null;
    try {
      ctx = new Context(Arch.Cpu);

      var out = new Tensor<I32>(ctx, [2]);
      var f = new Tensor<F32>(ctx, [1]);
      var graphOptionKernel:Kernel = Kernel.build(ctx, macro (out) -> {
        out[0] = 1;
      }, {graph: true});
      expectEq("descriptor_hash_length", graphOptionKernel.descriptorHash().length, 8);
      expectThrows("graph_do_while_arg_oob", "control argument index is out of range", function() {
        graphOptionKernel.launchGraphDoWhile(1, out);
      });
      graphOptionKernel.close();

      expectThrows("flat_index_oob", "flat index is out of bounds", function() {
        out.read(2);
      });
      expectThrows("bytes_range_oob", "range is out of bounds", function() {
        f.readBytes(new hl.Bytes(4), 1, 1);
      });

      var closedTensor = new Tensor<I32>(ctx, [1]);
      closedTensor.close();
      closedTensor.close();
      expectThrows("closed_tensor", "tensor is closed", function() {
        closedTensor.nativeHandle();
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
      var rank2 = new Tensor<I32>(ctx, [1, 2]);
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
      expectThrows("closed_context_tensor", "context is closed", function() {
        new Tensor<I32>(ctx, [1]);
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

  static function testStreamLaunch():Void {
    var ctx:Context = null;
    var k:Kernel = null;
    var stream:quadrants.Stream = null;
    var out:Tensor<I32> = null;
    try {
      ctx = new Context(Arch.Cpu);
      out = new Tensor<I32>(ctx, [1]);
      k = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
        out[0] = 42;
      });
      stream = ctx.stream();
      k.launchOn(stream, out);
      stream.sync();
      expectEq("stream_launch", out.read(0), 42);
      stream.close();
      stream = null;
      k.close();
      k = null;
      out.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (stream != null) {
        try {
          stream.close();
        } catch (_:Dynamic) {
        }
      }
      if (out != null) {
        try {
          out.close();
        } catch (_:Dynamic) {
        }
      }
      closeKernel(k);
      closeContext(ctx);
      throw e;
    }
  }

  static function testDLPackExport():Void {
    var ctx:Context = null;
    var tensor:Tensor<F32> = null;
    var dlpack:DLPackTensor = null;
    try {
      ctx = new Context(Arch.Cpu);
      tensor = new Tensor<F32>(ctx, [2, 3]);
      tensor.fill(7.0);
      expectEq("zero_copy_supported", tensor.supportsZeroCopy(), true);
      expectEq("dlpack_supported", tensor.supportsDLPack(), true);
      expectEq("external_pointer_import_supported", tensor.supportsExternalPointerImport(), true);
      var pointer = tensor.exportDevicePointer();
      if (Int64.compare(pointer, Int64.make(0, 0)) == 0) {
        throw "device_pointer_nonzero";
      }
      dlpack = tensor.exportDLPack();
      expectEq("dlpack_device_type_cpu", dlpack.deviceType(), 1);
      expectEq("dlpack_device_id", dlpack.deviceId(), 0);
      expectEq("dlpack_dtype_code_f32", dlpack.dtypeCode(), 2);
      expectEq("dlpack_dtype_bits_f32", dlpack.dtypeBits(), 32);
      expectEq("dlpack_dtype_lanes", dlpack.dtypeLanes(), 1);
      expectEq("dlpack_ndim", dlpack.ndim(), 2);
      expectInt64("dlpack_shape0", dlpack.shape(0), Int64.make(0, 2));
      expectInt64("dlpack_shape1", dlpack.shape(1), Int64.make(0, 3));
      expectInt64("dlpack_stride0", dlpack.stride(0), Int64.make(0, 3));
      expectInt64("dlpack_stride1", dlpack.stride(1), Int64.make(0, 1));
      expectInt64("dlpack_data_pointer", dlpack.dataPointer(), pointer);
      dlpack.close();
      dlpack = null;
      tensor.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (dlpack != null) {
        try {
          dlpack.close();
        } catch (_:Dynamic) {
        }
      }
      if (tensor != null) {
        try {
          tensor.close();
        } catch (_:Dynamic) {
        }
      }
      closeContext(ctx);
      throw e;
    }
  }

  public static function run():Void {
    testEnumIdsAndTensorMetadata();
    testPrimitiveHostDTypes();
    testPrimitiveBulkReadBytes();
    testProfilerContextOption();
    testKernelMigrationSmoke();
    testHostConvenienceContainers();
    testRuntimeValidation();
    testStreamLaunch();
    testDLPackExport();
  }
}
