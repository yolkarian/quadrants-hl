import quadrants.Algorithms;
import quadrants.Context;
import quadrants.Diagnostics;
import quadrants.Field;
import quadrants.Graph;
import quadrants.Kernel;
import quadrants.LayoutPolicy;
import quadrants.Mat3;
import quadrants.Matrix;
import quadrants.Mesh;
import quadrants.Mesh.MeshElementType;
import quadrants.Profiler;
import quadrants.Spec;
import quadrants.StructField;
import quadrants.StructTensor;
import quadrants.Tape;
import quadrants.Tensor;
import quadrants.Vec3;
import quadrants.Vector;
import quadrants.ad.CustomGradient;
import quadrants.ad.FwdMode;
import quadrants.algorithms.Scratch;
import quadrants.funcs.DeviceLinalg;
import quadrants.funcs.Linalg;
import quadrants.linalg.SparseSolver;
import quadrants.linalg.SparseSolverType;
import quadrants.mesh.Edge;
import quadrants.mesh.MeshAttribute;
import quadrants.mesh.MeshKinds;
import quadrants.mesh.MeshRelation;
import quadrants.mesh.Vertex;
import quadrants.quant.QuantBits;
import quadrants.quant.QuantSignedness;
import quadrants.quant.QuantizedF32Tensor;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.Types.U1;

@:build(quadrants.macro.QdArgs.build())
class V3RuntimeState {
  public var out:Tensor<I32>;
  public var n:Int;
  public var base:Int;

  public function new(ctx:Context, n:Int, base:Int) {
    this.out = new Tensor<I32>(ctx, [n]);
    this.n = n;
    this.base = base;
  }

  @:kernel
  public function fill(delta:Int):Void {
    for (i in 0...n) {
      out[i] = base + delta + i;
    }
  }
}

@:build(quadrants.macro.QdArgs.build())
class V3RuntimeNestedConfig {
  public var n:Int;
  public var base:Int;

  public function new(n:Int, base:Int) {
    this.n = n;
    this.base = base;
  }
}

@:build(quadrants.macro.QdArgs.build())
class V3RuntimeNestedState {
  public var out:Tensor<I32>;
  public var config:V3RuntimeNestedConfig;

  public function new(ctx:Context, n:Int, base:Int) {
    this.out = new Tensor<I32>(ctx, [n]);
    this.config = new V3RuntimeNestedConfig(n, base);
  }
}

@:build(quadrants.macro.QdStruct.build())
class V3RuntimeParticle {
  public var id:I32;
  public var mass:F32;
  public var pos:Vec3;
}

@:build(quadrants.macro.QdStruct.build())
class V3RuntimeWrapper {
  public var particle:V3RuntimeParticle;
  public var tag:I32;
}

@:build(quadrants.macro.QdStruct.build())
class V3RuntimeMatrixStruct {
  public var id:I32;
  public var transform:Mat3;
}

class V3RuntimeSemantic {
  static inline function eq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static inline function near(name:String, got:Float, expected:Float, eps:Float = 0.0001):Void {
    if (Math.abs(got - expected) > eps) throw '${name}: ${got} != ${expected}';
  }

  static function expectThrowsContains(name:String, needle:String, fn:Void->Void):Void {
    var ok = false;
    try {
      fn();
    } catch (e:Dynamic) {
      ok = Std.string(e).indexOf(needle) >= 0;
    }
    if (!ok) throw '${name}: expected error containing ${needle}';
  }

  static var goldenCache:Dynamic = null;

  static function golden():Dynamic {
    if (goldenCache == null) {
      goldenCache = haxe.Json.parse(sys.io.File.getContent("tests/parity/python_golden/v3_core.json"));
    }
    return goldenCache;
  }

  static function goldenArray(section:String, name:String):Array<Dynamic> {
    return cast Reflect.field(Reflect.field(golden(), section), name);
  }

  static function goldenInt(section:String, name:String):Int {
    return Std.int(Reflect.field(Reflect.field(golden(), section), name));
  }

  public static function run():Void {
    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true, profiler: true});
    try {
      testTypedKernelSpecAndField(ctx);
      testQdArgsAndStructTensor(ctx);
      testAdTapeAndCustomGradient(ctx);
      testStreamGraph(ctx);
      testAlgorithmsAndLinalg(ctx);
      testSparseMeshQuant(ctx);
      testDiagnosticsProfilerRelease(ctx);
    } catch (e:Dynamic) {
      try ctx.close() catch (_:Dynamic) {}
      throw e;
    }
    ctx.close();
  }

  static function testTypedKernelSpecAndField(ctx:Context):Void {
    var x = new Tensor<I32>(ctx, [4]);
    var y = new Tensor<I32>(ctx, [4]);
    for (i in 0...4) x.write(i, i + 1);
    var add = Kernel.build(ctx, macro (x:Tensor<I32>, y:Tensor<I32>, n:Spec<Int>) -> {
      for (i in 0...n) y[i] = x[i] + 10;
    }, {name: "v3_runtime_typed_spec"});
    add.launch(x, y, Spec.of(3));
    ctx.sync();
    eq("typed_spec_0", y.read(0), 11);
    eq("typed_spec_2", y.read(2), 13);
    eq("typed_spec_3_unwritten", y.read(3), 0);
    var oneValueBytes = x.readBytes(0, 1);
    y.write(0, 0);
    y.writeBytes(oneValueBytes, 0, 1);
    eq("tensor_bytes_roundtrip", y.read(0), x.read(0));
    if (x.supportsDLPack() != ctx.capabilities().interop.dlpack) throw "DLPack capability query mismatch";
    if (x.supportsExternalPointerImport() != ctx.capabilities().interop.externalPointerImport) throw "external pointer capability query mismatch";
    if (x.supportsExternalPointerImport()) {
      var pointerImported = new Tensor<I32>(ctx, [4]);
      pointerImported.importExternalPointer(x.devicePointer());
      eq("external_pointer_import_read", pointerImported.read(1), 2);
      pointerImported.write(1, 22);
      eq("external_pointer_import_alias", x.read(1), 22);
      pointerImported.close();
    }
    if (x.supportsDLPack()) {
      var dlpack = x.toDLPack();
      eq("dlpack_ndim", dlpack.ndim(), 1);
      if (dlpack.shape(0) != 4) throw "dlpack_shape";
      if (dlpack.stride(0) != 1) throw "dlpack_stride";
      eq("dlpack_dtype_bits", dlpack.dtypeBits(), 32);
      eq("dlpack_dtype_lanes", dlpack.dtypeLanes(), 1);
      var dlpackImported = new Tensor<I32>(ctx, [4]);
      dlpackImported.importDLPack(dlpack);
      eq("dlpack_import_read", dlpackImported.read(1), 22);
      dlpackImported.write(2, 33);
      eq("dlpack_import_alias", x.read(2), 33);
      dlpackImported.close();
    }

    var field = new Field<I32>(ctx, [4]);
    var fieldOut = new Tensor<I32>(ctx, [4]);
    var fieldKernel = Kernel.build(ctx, macro (field:Field<I32>, out:Tensor<I32>, n:Int) -> {
      for (i in 0...n) {
        field[i] = i * 2;
        out[i] = field[i] + 1;
      }
    }, {name: "v3_runtime_field_param"});
    fieldKernel.launch(field, fieldOut, 4);
    ctx.sync();
    eq("field_param_3", field.read(3), 6);
    eq("field_param_out3", fieldOut.read(3), 7);

    var offsetField = new Field<I32>(ctx);
    var offsetOut = new Tensor<I32>(ctx, [4]);
    new quadrants.FieldsBuilder(ctx).dense(quadrants.Axis.i, 4).offset([10]).place(cast offsetField);
    offsetField.write(0, 41);
    eq("field_offset_host", offsetField.read(0), 41);
    var offsetKernel = Kernel.build(ctx, macro (field:Field<I32>, out:Tensor<I32>) -> {
      for (i in 0...4) {
        field[i + 10] = i + 20;
        out[i] = field[i + 10];
      }
    }, {name: "v3_runtime_field_offset"});
    offsetKernel.launch(offsetField, offsetOut);
    ctx.sync();
    eq("field_offset_kernel_0", offsetOut.read(0), 20);
    eq("field_offset_kernel_3", offsetOut.read(3), 23);
    eq("field_offset_host_after_kernel", offsetField.read(3), 23);
    offsetKernel.close();
    offsetField.close();
    offsetOut.close();

    fieldKernel.close();
    field.close();
    fieldOut.close();
    add.close();
    x.close();
    y.close();
  }

  static function testQdArgsAndStructTensor(ctx:Context):Void {
    var state = new V3RuntimeState(ctx, 4, 20);
    state.fill(3);
    ctx.sync();
    eq("qdargs_kernel_0", state.out.read(0), 23);
    eq("qdargs_kernel_3", state.out.read(3), 26);

    var nestedState = new V3RuntimeNestedState(ctx, 4, 30);
    var nestedKernel = Kernel.build(ctx, macro (state:V3RuntimeNestedState, delta:Spec<Int>) -> {
      for (i in 0...state.config.n) {
        state.out[i] = state.config.base + delta + i;
      }
    }, {name: "v3_runtime_nested_qdargs"});
    nestedKernel.launch(nestedState, Spec.of(2));
    ctx.sync();
    eq("nested_qdargs_0", nestedState.out.read(0), 32);
    eq("nested_qdargs_3", nestedState.out.read(3), 35);
    nestedState.config.base = 40;
    nestedKernel.launch(nestedState, Spec.of(5));
    ctx.sync();
    eq("nested_qdargs_spec_update_0", nestedState.out.read(0), 45);
    eq("nested_qdargs_spec_update_3", nestedState.out.read(3), 48);
    nestedKernel.close();

    var particles:StructTensor<V3RuntimeParticle> = StructTensor.alloc(ctx, [2], LayoutPolicy.AOS);
    particles.writeMember("id", 0, 7);
    particles.writeMember("mass", 0, 2.5);
    var posTensor:Dynamic = particles.member("pos");
    posTensor.writeAt([0, 0], 1.0);
    var bump = Kernel.build(ctx, macro (particles:StructTensor<V3RuntimeParticle>, n:Spec<Int>) -> {
      for (i in 0...n) {
        var p = particles[i];
        p.id = p.id + 1;
        p.mass = p.mass + 0.5;
        p.pos.x = p.pos.x + 2.0;
        particles[i] = p;
      }
    }, {name: "v3_runtime_struct_tensor"});
    bump.launch(particles, Spec.of(1));
    ctx.sync();
    eq("struct_id", particles.readMember("id", 0), 8);
    near("struct_mass", particles.readMember("mass", 0), 3.0);
    near("struct_pos", posTensor.readAt([0, 0]), 3.0);
    bump.close();
    particles.close();

    var wrappers:StructTensor<V3RuntimeWrapper> = StructTensor.alloc(ctx, [1], LayoutPolicy.AOS);
    wrappers.writeMember("particle.id", 0, 3);
    var nested = Kernel.build(ctx, macro (wrappers:StructTensor<V3RuntimeWrapper>) -> {
      var w = wrappers[0];
      w.particle.id = w.particle.id + 4;
      wrappers[0] = w;
    }, {name: "v3_runtime_nested_struct_tensor"});
    nested.launch(wrappers);
    ctx.sync();
    eq("nested_struct", wrappers.readMember("particle.id", 0), 7);
    nested.close();
    wrappers.close();

    var matrixStruct:StructTensor<V3RuntimeMatrixStruct> = StructTensor.alloc(ctx, [1], LayoutPolicy.AOS);
    matrixStruct.writeMember("id", 0, 21);
    var transformTensor:Dynamic = matrixStruct.member("transform");
    transformTensor.writeAt([0, 0], 1.0);
    transformTensor.writeAt([0, 4], 2.0);
    var matrixOut = new Tensor<F32>(ctx, [1]);
    var matrixKernel = Kernel.build(ctx, macro (items:StructTensor<V3RuntimeMatrixStruct>, out:Tensor<F32>) -> {
      var item = items[0];
      item.transform.m00 = item.transform.m00 + item.transform.m11;
      items[0] = item;
      out[0] = item.transform.m00;
    }, {name: "v3_runtime_struct_matrix_member"});
    matrixKernel.launch(matrixStruct, matrixOut);
    ctx.sync();
    near("struct_matrix_out", matrixOut.read(0), 3.0);
    near("struct_matrix_store", transformTensor.readAt([0, 0]), 3.0);
    matrixKernel.close();
    matrixOut.close();
    matrixStruct.close();

    var structField:StructField<V3RuntimeParticle> = StructField.alloc(ctx, [1], LayoutPolicy.SOA);
    structField.writeMember("id", 0, 10);
    structField.writeMember("mass", 0, 4.0);
    var fieldKernel = Kernel.build(ctx, macro (particles:StructField<V3RuntimeParticle>) -> {
      var p = particles[0];
      p.id = p.id + 5;
      p.mass = p.mass + 1.0;
      particles[0] = p;
    }, {name: "v3_runtime_struct_field"});
    fieldKernel.launch(structField);
    ctx.sync();
    eq("struct_field_id", structField.readMember("id", 0), 15);
    near("struct_field_mass", structField.readMember("mass", 0), 5.0);
    fieldKernel.close();
    structField.close();
    nestedState.out.close();
    state.out.close();
  }

  static function testAdTapeAndCustomGradient(ctx:Context):Void {
    ctx.setAdstackConfig(true, 4096, 0);
    var x = new Tensor<F32>(ctx, [3]);
    var out = new Tensor<F32>(ctx, [3]);
    x.enableGrad();
    out.enableGrad();
    x.fromArray([2.0, 3.0, 4.0]);
    out.fill(0.0);
    var squareDirect = Kernel.build(ctx, macro (x:Tensor<F32>, out:Tensor<F32>, n:Int) -> {
      for (i in 0...n) {
        out[i] = x[i] * x[i] + 1.0;
      }
    }, {name: "v3_runtime_ad_square"});
    squareDirect.launch(x, out, 3);
    ctx.sync();
    near("ad_primal0", out.read(0), 5.0);
    near("ad_primal2", out.read(2), 17.0);
    x.grad.fill(0.0);
    out.grad.fill(1.0);
    var gradKernel = squareDirect.grad();
    gradKernel.launch(x, out, 3);
    ctx.sync();
    near("ad_grad0", x.grad.read(0), 4.0);
    near("ad_grad2", x.grad.read(2), 8.0);

    var forwardKernel = squareDirect.forwardGrad();
    x.dual.fromArray([1.0, 2.0, 3.0]);
    out.dual.fill(0.0);
    forwardKernel.launch(x, out, 3);
    ctx.sync();
    near("ad_fwd0", out.dual.read(0), 4.0);
    near("ad_fwd2", out.dual.read(2), 24.0);

    var validationKernel = squareDirect.validationKernel();
    out.fill(0.0);
    validationKernel.launch(x, out, 3);
    ctx.sync();
    near("ad_validation", out.read(1), 10.0);

    var invalidValidation = Kernel.build(ctx, macro (x:Tensor<F32>, out:Tensor<F32>) -> {
      x[0] = x[0] + 1.0;
      out[0] = x[0];
    }, {name: "v3_runtime_ad_invalid_read_after_write"});
    expectThrowsContains("ad_validation_read_after_write", "read-after-write", function() invalidValidation.validationKernel());
    invalidValidation.close();

    var whileOut = new Tensor<F32>(ctx, [3]);
    whileOut.enableGrad();
    whileOut.fill(0.0);
    var whileKernel = Kernel.build(ctx, macro (x:Tensor<F32>, out:Tensor<F32>, n:Int) -> {
      var i = 0;
      while (i < n) {
        out[i] = x[i] * x[i];
        i = i + 1;
      }
    }, {name: "v3_runtime_ad_dynamic_while"});
    whileKernel.launch(x, whileOut, 3);
    ctx.sync();
    near("ad_dynamic_while_forward", whileOut.read(2), 16.0);
    expectThrowsContains("ad_dynamic_while_grad_unsupported", "dynamic while", function() whileKernel.grad());
    whileKernel.close();
    whileOut.close();

    var input = new Tensor<F32>(ctx, [3]);
    var mid = new Tensor<F32>(ctx, [3]);
    var loss = new Tensor<F32>(ctx, [1]);
    input.enableGrad();
    mid.enableGrad();
    loss.enableGrad();
    input.fromArray([1.0, 2.0, 3.0]);
    mid.fill(0.0);
    loss.fill(0.0);
    var square = Kernel.build(ctx, macro (input:Tensor<F32>, mid:Tensor<F32>, n:Int) -> {
      for (i in 0...n) mid[i] = input[i] * input[i];
    }, {name: "v3_runtime_tape_square"});
    var reduce = Kernel.build(ctx, macro (mid:Tensor<F32>, loss:Tensor<F32>, n:Int) -> {
      for (i in 0...n) loss[0] += mid[i];
    }, {name: "v3_runtime_tape_reduce"});
    var tape = new Tape();
    square.launchTape(tape, input, mid, 3);
    reduce.launchTape(tape, mid, loss, 3);
    ctx.sync();
    near("tape_loss", loss.read(0), 14.0);
    input.grad.fill(0.0);
    mid.grad.fill(0.0);
    loss.grad.fill(1.0);
    tape.backward(true);
    ctx.sync();
    eq("tape_clear", tape.length, 0);
    near("tape_grad0", input.grad.read(0), 2.0);
    near("tape_grad2", input.grad.read(2), 6.0);

    input.fromArray([1.0, 2.0, 3.0]);
    mid.fill(0.0);
    loss.fill(0.0);
    var withLossTape = Tape.withLoss(ctx, loss, function(t) {
      square.launchTape(t, input, mid, 3);
      reduce.launchTape(t, mid, loss, 3);
    }, true);
    eq("with_loss_clear", withLossTape.length, 0);
    near("with_loss_grad1", input.grad.read(1), 4.0);

    input.fromArray([1.0, 2.0, 3.0]);
    mid.fill(0.0);
    loss.fill(0.0);
    var fwdModeTape = FwdMode.run(input, loss, 1.0, function(t) {
      square.launchTape(t, input, mid, 3);
      reduce.launchTape(t, mid, loss, 3);
    }, true);
    eq("fwd_mode_clear", fwdModeTape.length, 0);
    near("fwd_mode_dual", loss.dual.read(0), 12.0);

    var paused = new Tape();
    paused.pause();
    square.launchTape(paused, input, mid, 3);
    eq("tape_pause", paused.length, 0);
    paused.resume();
    square.launchTape(paused, input, mid, 3);
    eq("tape_resume", paused.length, 1);
    paused.clear();
    eq("tape_clear_manual", paused.length, 0);

    var custom = CustomGradient.register(square, {
      backward: square.grad(),
      forwardGrad: square.forwardGrad(),
      validation: square.validationKernel(),
    });
    if (custom == null) throw "custom gradient register failed";

    var marker = new Tensor<I32>(ctx, [1]);
    marker.write(0, 0);
    var customForward = Kernel.build(ctx, macro (marker:Tensor<I32>) -> {
      marker[0] = marker[0] + 1;
    }, {name: "v3_runtime_custom_forward"});
    var customBackward = Kernel.build(ctx, macro (marker:Tensor<I32>) -> {
      marker[0] = marker[0] + 10;
    }, {name: "v3_runtime_custom_backward"});
    CustomGradient.register(customForward, {backward: customBackward});
    var customTape = new Tape();
    customForward.launchTape(customTape, marker);
    ctx.sync();
    eq("custom_forward_marker", marker.read(0), 1);
    customTape.backward(true);
    ctx.sync();
    eq("custom_backward_replacement", marker.read(0), 11);
    eq("custom_tape_clear", customTape.length, 0);

    var intNoGrad = new Tensor<I32>(ctx, [1]);
    expectThrowsContains("i32_tensor_enable_grad", "real floating dtype", function() intNoGrad.enableGrad());
    expectThrowsContains("i32_tensor_grad", "real floating dtype", function() { var unused = intNoGrad.grad; });
    var boolNoGrad = new Tensor<U1>(ctx, [1]);
    expectThrowsContains("u1_tensor_enable_grad", "real floating dtype", function() boolNoGrad.enableGrad());
    var intFieldNoGrad = new Field<I32>(ctx, [1]);
    expectThrowsContains("i32_field_grad", "real floating dtype", function() { var unused = intFieldNoGrad.grad; });

    customForward.close();
    customBackward.close();
    marker.close();
    intNoGrad.close();
    boolNoGrad.close();
    intFieldNoGrad.close();

    squareDirect.close();
    gradKernel.close();
    forwardKernel.close();
    validationKernel.close();
    square.close();
    reduce.close();
    x.close();
    out.close();
    input.close();
    mid.close();
    loss.close();
  }

  static function testStreamGraph(ctx:Context):Void {
    var x = new Tensor<I32>(ctx, [1]);
    var control = new Tensor<I32>(ctx, [1]);
    x.write(0, 0);
    control.write(0, 2);
    var inc = Kernel.build(ctx, macro (x:Tensor<I32>, control:Tensor<I32>) -> {
      x[0] = x[0] + 1;
      control[0] = control[0] - 1;
    }, {name: "v3_runtime_stream_graph"});
    var stream = ctx.createStream();
    inc.launchOn(stream, x, control);
    stream.sync();
    eq("stream_launch", x.read(0), 1);
    inc.launchGraph(x, control);
    ctx.sync();
    eq("graph_launch", x.read(0), 2);
    control.write(0, 2);
    inc.launchGraphWhile(control, x, control);
    ctx.sync();
    eq("graph_while_x", x.read(0), 4);
    eq("graph_while_control", control.read(0), 0);
    control.write(0, 2);
    inc.launchGraphDoWhile(control, x, control);
    ctx.sync();
    eq("graph_dowhile_x", x.read(0), 6);
    eq("graph_dowhile_control", control.read(0), 0);
    Graph.parallel(ctx, [function() inc.launchOn(Graph.autoStream(), x, control)]);
    ctx.sync();
    eq("graph_parallel", x.read(0), 7);
    expectThrowsContains("graph_parallel_multi_capability", "capability streamParallel", function() Graph.parallel(ctx, [function() {}, function() {}]));
    var sequenceMarker = 0;
    Graph.sequence(ctx, [function() sequenceMarker += 1, function() sequenceMarker += 2]);
    eq("graph_sequence", sequenceMarker, 3);
    expectThrowsContains("ad_stream_restriction", "Tape launch on explicit streams", function() inc.launchTapeOn(stream, new Tape(), x, control));
    if (ctx.capabilities().streams.events) {
      control.write(0, 1);
      inc.launchOn(stream, x, control);
      var event = ctx.createEvent();
      event.record(stream);
      var other = ctx.createStream();
      other.wait(event);
      other.sync();
      ctx.sync();
      eq("stream_event_ordering", x.read(0), 8);
      event.close();
      other.close();
    } else {
      expectThrowsContains("stream_event_capability", "stream events require", function() ctx.createEvent());
    }
    stream.close();
    inc.close();
    x.close();
    control.close();
  }

  static function testAlgorithmsAndLinalg(ctx:Context):Void {
    var scratch = Scratch.create(ctx);
    scratch.reserve(1024);
    scratch.clear();
    var input = new Tensor<I32>(ctx, [5]);
    input.fromArray([3, 1, 4, 1, 5]);
    var out = new Tensor<I32>(ctx, [5]);
    Algorithms.reduceAdd(ctx, input, out, scratch);
    ctx.sync();
    eq("reduce_add", out.read(0), goldenInt("algorithms", "reduceAdd"));
    Algorithms.reduceMin(ctx, input, out, scratch);
    ctx.sync();
    eq("reduce_min", out.read(0), goldenInt("algorithms", "reduceMin"));
    Algorithms.exclusiveScanAdd(ctx, input, out, scratch);
    ctx.sync();
    eq("scan0", out.read(0), 0);
    eq("scan1", out.read(1), 3);
    eq("scan4", out.read(4), 9);
    var flags = new Tensor<I32>(ctx, [5]);
    flags.fromArray([1, 0, 1, 0, 1]);
    var count = new Tensor<I32>(ctx, [1]);
    count.write(0, 0);
    Algorithms.select(ctx, input, flags, out, count, scratch);
    ctx.sync();
    eq("select_count", count.read(0), 3);
    eq("select2", out.read(2), 5);
    var keys = new Tensor<I32>(ctx, [5]);
    var tmpKeys = new Tensor<I32>(ctx, [5]);
    keys.fromArray([4, 1, 3, 2, 0]);
    Algorithms.radixSort(ctx, keys, tmpKeys, scratch);
    ctx.sync();
    var sortGolden = goldenArray("algorithms", "radixSort");
    eq("sort0", tmpKeys.read(0), Std.int(sortGolden[0]));
    eq("sort4", tmpKeys.read(4), Std.int(sortGolden[4]));
    keys.fromArray([2, 1, 2, 1, 3]);
    var vals = new Tensor<I32>(ctx, [5]);
    vals.fromArray([20, 10, 21, 11, 30]);
    var tmpVals = new Tensor<I32>(ctx, [5]);
    Algorithms.radixSortPairs(ctx, keys, tmpKeys, vals, tmpVals, scratch);
    ctx.sync();
    eq("sort_pairs_k0", tmpKeys.read(0), 1);
    eq("sort_pairs_v0", tmpVals.read(0), 10);
    keys.fromArray([1, 1, 2, 2, 2]);
    vals.fromArray([3, 4, 5, 6, 7]);
    var outKeys = new Tensor<I32>(ctx, [5]);
    var outVals = new Tensor<I32>(ctx, [5]);
    count.write(0, 0);
    Algorithms.reduceByKeyAdd(ctx, keys, vals, outKeys, outVals, count, scratch);
    ctx.sync();
    eq("reduce_by_key_count", count.read(0), 2);
    var rbkValues = goldenArray("algorithms", "reduceByKeyValues");
    eq("reduce_by_key_v0", outVals.read(0), Std.int(rbkValues[0]));
    eq("reduce_by_key_v1", outVals.read(1), Std.int(rbkValues[1]));

    var solve = Linalg.solve3(Matrix.ofArray(3, 3, [2.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0, 0.0, 5.0]), Vector.ofArray([6.0, 8.0, 20.0]));
    var solveGolden = goldenArray("linalg", "solve3");
    near("solve3_0", solve[0], solveGolden[0]);
    near("solve3_2", solve[2], solveGolden[2]);
    var eig = Linalg.symEig3(Matrix.ofArray(3, 3, [1.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 2.0]));
    near("sym_eig3_0", eig.values[0], 3.0);
    near("sym_eig3_2", eig.values[2], 1.0);
    var svd = Linalg.svd3(Matrix.ofArray(3, 3, [4.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 2.0]));
    near("svd3_0", svd.sigma[0], 4.0);
    near("svd3_2", svd.sigma[2], 2.0);
    var polar = Linalg.polar2(Matrix.ofArray(2, 2, [1.0, 0.0, 0.0, 2.0]));
    near("polar_p", polar.p.get(1, 1), 2.0);
    var spd = Linalg.makeSpd(Matrix.ofArray(2, 2, [1.0, 2.0, 2.0, -1.0]));
    if (spd.get(0, 0) <= 0.0) throw "makeSpd failed";

    var deviceLinalgOut = new Tensor<F32>(ctx, [5]);
    var deviceLinalgKernel = Kernel.build(ctx, macro (out:Tensor<F32>) -> {
      var a2 = Matrix.ofArray(2, 2, [2.0, 0.0, 0.0, 4.0]);
      var b2 = Matrix.ofArray(2, 1, [6.0, 8.0]);
      out[0] = DeviceLinalg.solve2X(a2.kernelGet(0, 0), a2.kernelGet(0, 1), a2.kernelGet(1, 0), a2.kernelGet(1, 1), b2.kernelGet(0, 0), b2.kernelGet(1, 0));
      out[1] = DeviceLinalg.solve2Y(a2.kernelGet(0, 0), a2.kernelGet(0, 1), a2.kernelGet(1, 0), a2.kernelGet(1, 1), b2.kernelGet(0, 0), b2.kernelGet(1, 0));
      var a3 = Matrix.ofArray(3, 3, [2.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0, 0.0, 5.0]);
      var b3 = Matrix.ofArray(3, 1, [6.0, 8.0, 20.0]);
      out[2] = DeviceLinalg.solve3X(a3.kernelGet(0, 0), a3.kernelGet(0, 1), a3.kernelGet(0, 2), a3.kernelGet(1, 0), a3.kernelGet(1, 1), a3.kernelGet(1, 2), a3.kernelGet(2, 0), a3.kernelGet(2, 1), a3.kernelGet(2, 2), b3.kernelGet(0, 0), b3.kernelGet(1, 0), b3.kernelGet(2, 0));
      out[3] = DeviceLinalg.solve3Y(a3.kernelGet(0, 0), a3.kernelGet(0, 1), a3.kernelGet(0, 2), a3.kernelGet(1, 0), a3.kernelGet(1, 1), a3.kernelGet(1, 2), a3.kernelGet(2, 0), a3.kernelGet(2, 1), a3.kernelGet(2, 2), b3.kernelGet(0, 0), b3.kernelGet(1, 0), b3.kernelGet(2, 0));
      out[4] = DeviceLinalg.solve3Z(a3.kernelGet(0, 0), a3.kernelGet(0, 1), a3.kernelGet(0, 2), a3.kernelGet(1, 0), a3.kernelGet(1, 1), a3.kernelGet(1, 2), a3.kernelGet(2, 0), a3.kernelGet(2, 1), a3.kernelGet(2, 2), b3.kernelGet(0, 0), b3.kernelGet(1, 0), b3.kernelGet(2, 0));
    }, {name: "v3_runtime_device_linalg", helpers: [DeviceLinalg]});
    deviceLinalgKernel.launch(deviceLinalgOut);
    ctx.sync();
    near("device_linalg_solve2_0", deviceLinalgOut.read(0), 3.0);
    near("device_linalg_solve2_1", deviceLinalgOut.read(1), 2.0);
    near("device_linalg_solve3_2", deviceLinalgOut.read(4), solveGolden[2]);

    deviceLinalgKernel.close();
    deviceLinalgOut.close();
    input.close();
    out.close();
    flags.close();
    count.close();
    keys.close();
    tmpKeys.close();
    vals.close();
    tmpVals.close();
    outKeys.close();
    outVals.close();
  }

  static function testSparseMeshQuant(ctx:Context):Void {
    var dense = new Tensor<F32>(ctx, [2, 2]);
    dense.fromArray([2.0, 0.0, 0.0, 5.0]);
    var sparse = new quadrants.linalg.SparseMatrix<F32>(ctx, 2, 2, DType.F32);
    sparse.buildFromTensor(dense, {eps: 0.0});
    eq("sparse_nnz", sparse.nnz, 2);
    near("sparse_get", sparse.get(1, 1), 5.0);
    var xv = new Tensor<F32>(ctx, [2]);
    var yv = new Tensor<F32>(ctx, [2]);
    xv.fromArray([3.0, 4.0]);
    sparse.matvec(xv, yv);
    ctx.sync();
    var sparseGolden = goldenArray("sparse", "matvec");
    near("sparse_matvec0", yv.read(0), sparseGolden[0]);
    near("sparse_matvec1", yv.read(1), sparseGolden[1]);
    var rhs = new Tensor<F32>(ctx, [2]);
    var solution = new Tensor<F32>(ctx, [2]);
    rhs.fromArray([6.0, 20.0]);
    var solver = new SparseSolver<F32>(ctx, DType.F32, SparseSolverType.LU, quadrants.linalg.SparseOrdering.COLAMD, true);
    solver.solve(sparse, rhs, solution);
    ctx.sync();
    var sparseSolveGolden = goldenArray("sparse", "solve");
    near("sparse_solve0", solution.read(0), sparseSolveGolden[0]);
    near("sparse_solve1", solution.read(1), sparseSolveGolden[1]);
    var sparsePath = "build/v3_runtime_sparse.mtx";
    sparse.mmwrite(sparsePath);
    var content = sys.io.File.getContent(sparsePath);
    if (content.indexOf("2 2 2") < 0 || content.indexOf("2 2 5") < 0) throw "sparse mmwrite failed";
    var mmRoundtrip = quadrants.linalg.SparseMatrix.mmread(ctx, sparsePath, DType.F32);
    eq("sparse_mmread_nnz", mmRoundtrip.nnz, 2);
    near("sparse_mmread_value", mmRoundtrip.get(1, 1), 5.0);

    var cooRows = new Tensor<I32>(ctx, [2]);
    var cooCols = new Tensor<I32>(ctx, [2]);
    var cooVals = new Tensor<F32>(ctx, [2]);
    eq("sparse_to_coo_count", sparse.toCOO(cooRows, cooCols, cooVals), 2);
    eq("sparse_to_coo_row0", cooRows.read(0), 0);
    eq("sparse_to_coo_col1", cooCols.read(1), 1);
    near("sparse_to_coo_val1", cooVals.read(1), 5.0);
    var cooRoundtrip = quadrants.linalg.SparseMatrix.fromCOO(ctx, cooRows, cooCols, cooVals, 2, 2);
    near("sparse_from_coo", cooRoundtrip.get(1, 1), 5.0);
    var csrRowPtr = new Tensor<I32>(ctx, [3]);
    var csrCols = new Tensor<I32>(ctx, [2]);
    var csrVals = new Tensor<F32>(ctx, [2]);
    eq("sparse_to_csr_count", sparse.toCSR(csrRowPtr, csrCols, csrVals), 2);
    eq("sparse_to_csr_rowptr1", csrRowPtr.read(1), 1);
    eq("sparse_to_csr_rowptr2", csrRowPtr.read(2), 2);
    var csrRoundtrip = quadrants.linalg.SparseMatrix.fromCSR(ctx, csrRowPtr, csrCols, csrVals, 2, 2);
    near("sparse_from_csr", csrRoundtrip.get(0, 0), 2.0);

    var mesh = new Mesh(3, 2);
    var e0 = mesh.element(MeshKinds.edge, 0);
    var e1 = mesh.element(MeshKinds.edge, 1);
    var v0 = mesh.element(MeshKinds.vertex, 0);
    var v1 = mesh.element(MeshKinds.vertex, 1);
    var v2 = mesh.element(MeshKinds.vertex, 2);
    var relation:MeshRelation<Edge, Vertex> = mesh.relation(MeshKinds.edge, MeshKinds.vertex);
    relation.set(e0, [v0, v1]);
    relation.set(e1, [v1, v2]);
    var massField = new Field<I32>(ctx, [3]);
    var mass:MeshAttribute<Vertex, I32> = mesh.attribute(MeshKinds.vertex, massField);
    mass.write(v0, 5);
    mass.write(v1, 6);
    mass.write(v2, 7);
    var edgeSum = new Tensor<I32>(ctx, [2]);
    var meshKernel = Kernel.build(ctx, macro (relation:MeshRelation<Edge, Vertex>, mass:MeshAttribute<Vertex, I32>, edgeSum:Tensor<I32>) -> {
      for (e in 0...2) {
        var sum = 0;
        for (j in 0...relation.size(e)) sum = sum + mass.read(relation.get(e, j));
        edgeSum[e] = sum;
      }
    }, {name: "v3_runtime_mesh"});
    meshKernel.launch(relation, mass, edgeSum);
    ctx.sync();
    var meshGolden = goldenArray("mesh", "edgeSums");
    eq("mesh_edge0", edgeSum.read(0), Std.int(meshGolden[0]));
    eq("mesh_edge1", edgeSum.read(1), Std.int(meshGolden[1]));
    var meshPath = "build/v3_runtime_mesh.json";
    mesh.save(meshPath);
    var loadedMesh = Mesh.load(ctx, meshPath);
    eq("mesh_load_count", loadedMesh.count(MeshElementType.Vertex), 3);
    eq("mesh_load_relation", loadedMesh.relationAccess(MeshElementType.Edge, 1, MeshElementType.Vertex, 1), 2);
    var reorderedMesh = mesh.reorder(MeshElementType.Vertex, [2, 0, 1]);
    eq("mesh_reorder_target0", reorderedMesh.relationAccess(MeshElementType.Edge, 0, MeshElementType.Vertex, 0), 1);
    eq("mesh_reorder_target1", reorderedMesh.relationAccess(MeshElementType.Edge, 1, MeshElementType.Vertex, 1), 0);

    var qspec = quadrants.quant.Quant.fixedF32(QuantBits.Bits8, QuantSignedness.Signed, 4);
    var qvalues = new QuantizedF32Tensor(ctx, [2], qspec);
    qvalues.write(0, 1.25);
    qvalues.write(1, -1.0);
    var qout = new Tensor<F32>(ctx, [2]);
    var qKernel = Kernel.build(ctx, macro (qvalues:QuantizedF32Tensor, qout:Tensor<F32>) -> {
      qout[0] = qvalues.read(0) + 1.0;
      qout[1] = qvalues.read(1) - 1.0;
      qvalues.write(0, qout[0]);
      qvalues.write(1, qout[1]);
    }, {name: "v3_runtime_quant"});
    qKernel.launch(qvalues, qout);
    ctx.sync();
    var quantGolden = goldenArray("quant", "outputs");
    near("quant_read0", qout.read(0), quantGolden[0]);
    near("quant_read1", qout.read(1), quantGolden[1]);
    eq("quant_raw0", qvalues.readRaw(0), goldenInt("quant", "raw0"));
    eq("quant_raw1", qvalues.readRaw(1), goldenInt("quant", "raw1"));
    qvalues.write(1, 999.0);
    eq("quant_saturate_max", qvalues.readRaw(1), goldenInt("quant", "saturateMax"));
    qvalues.write(1, -999.0);
    eq("quant_saturate_min", qvalues.readRaw(1), goldenInt("quant", "saturateMin"));

    var qfloatField = new Field<F32>(ctx);
    var qfloatSpec = quadrants.quant.Quant.floatF32(5, 10, QuantSignedness.Signed);
    ctx.root.dense(quadrants.Axis.i, 1).bitStruct(32).placeQuant(qfloatField, qfloatSpec);
    qfloatField.write(0, 1.5);
    near("quant_float", qfloatField.read(0), 1.5, 0.1);

    qfloatField.close();
    qKernel.close();
    qvalues.close();
    qout.close();
    meshKernel.close();
    edgeSum.close();
    massField.close();
    solver.close();
    rhs.close();
    solution.close();
    cooRoundtrip.close();
    csrRoundtrip.close();
    mmRoundtrip.close();
    cooRows.close();
    cooCols.close();
    cooVals.close();
    csrRowPtr.close();
    csrCols.close();
    csrVals.close();
    sparse.close();
    dense.close();
    xv.close();
    yv.close();
  }

  static function testDiagnosticsProfilerRelease(ctx:Context):Void {
    var caps:Dynamic = Diagnostics.dumpCapabilities(ctx);
    if (!caps.fieldResourceParam || !caps.structTensor || !caps.quantKernelParam) throw "capability dump failed";
    Profiler.withScope(ctx, "v3_runtime_scope", function() ctx.sync());
    if (ctx.profiler().traceEvents().length == 0) throw "profiler trace events failed";
    var memoryStats = ctx.profiler().memoryStats();
    if (!memoryStats.available) throw "memory profiler stats unavailable";
    var health:Dynamic = Diagnostics.health(ctx);
    if (health == null) throw "diagnostics health failed";
    var version = ctx.capabilities().version;
    if (version.descriptorVersion != quadrants.VersionInfo.DESCRIPTOR_VERSION) throw "version descriptor mismatch";
  }
}
