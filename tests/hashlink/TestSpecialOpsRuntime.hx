import haxe.Int64;
import quadrants.Kernel;
import quadrants.SpecialOps;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.Types.U32;

class TestSpecialOpsRuntime {
  static inline var SECTION_STATEMENTS = 7;
  static inline var STMT_RETURN_VALUE = 12;
  static inline var EXPR_VOLATILE_LOAD_INDEX = 88;
  static inline var EXPR_FREXP_SIGNIFICAND = 89;
  static inline var EXPR_FNS_U32 = 91;

  static function i64(value:Int):Int64 {
    return Int64.make(0, value);
  }

  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectInt64(name:String, got:Int64, expected:Int64):Void {
    if (Int64.compare(got, expected) != 0) throw '${name}: ${got} != ${expected}';
  }

  static function expectFloat(name:String, got:Float, expected:Float, eps:Float = 0.0001):Void {
    if (Math.abs(got - expected) > eps) throw '${name}: ${got} != ${expected}';
  }

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static function sectionOffset(bytes:hl.Bytes, kind:Int):Int {
    var sectionCount = u32(bytes, 8);
    for (i in 0...sectionCount) {
      var entry = 20 + i * 12;
      if (u32(bytes, entry) == kind) return u32(bytes, entry + 4);
    }
    throw 'descriptor section ${kind} is missing';
  }

  static function expectDescriptorOpcodes():Void {
    var volatileDescriptor = Kernel.descriptorBytes(macro (input:Tensor<I32>) -> {
      return SpecialOps.volatileLoad(input[0]);
    });
    var statementsOffset = sectionOffset(volatileDescriptor, SECTION_STATEMENTS);
    expectEq("volatile_statement_count", u32(volatileDescriptor, statementsOffset + 4), 1);
    expectEq("volatile_statement_opcode", volatileDescriptor.getUI8(statementsOffset + 8), STMT_RETURN_VALUE);
    expectEq("volatile_expr_opcode", volatileDescriptor.getUI8(statementsOffset + 9), EXPR_VOLATILE_LOAD_INDEX);

    var fnsDescriptor = Kernel.descriptorBytes(macro (mask:U32) -> {
      return SpecialOps.fnsU32(mask, 2, 1);
    });
    statementsOffset = sectionOffset(fnsDescriptor, SECTION_STATEMENTS);
    expectEq("fns_expr_opcode", fnsDescriptor.getUI8(statementsOffset + 9), EXPR_FNS_U32);

    var frexpDescriptor = Kernel.descriptorBytes(macro (x:F32) -> {
      return SpecialOps.frexpF32(x).significand;
    });
    statementsOffset = sectionOffset(frexpDescriptor, SECTION_STATEMENTS);
    expectEq("frexp_expr_opcode", frexpDescriptor.getUI8(statementsOffset + 9), EXPR_FREXP_SIGNIFICAND);
  }

  public static function run():Void {
    expectDescriptorOpcodes();
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var kernels:Array<Kernel> = [];
      try {
        var rawOut = new Tensor<I32>(ctx, [8]);
        var rawKernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
          out[0] = SpecialOps.rawDiv(-7, 3);
          out[1] = SpecialOps.rawMod(-7, 3);
          out[2] = SpecialOps.rawDiv(7, -3);
          out[3] = SpecialOps.rawMod(7, -3);
          out[4] = SpecialOps.rawDiv(-7, -3);
          out[5] = SpecialOps.rawMod(-7, -3);
          out[6] = SpecialOps.rawDiv(7, 3);
          out[7] = SpecialOps.rawMod(7, 3);
        });
        kernels.push(rawKernel);
        rawKernel.launch(rawOut);
        ctx.sync();
        expectEq("raw_div_neg_pos", rawOut.read(0), -2);
        expectEq("raw_mod_neg_pos", rawOut.read(1), -1);
        expectEq("raw_div_pos_neg", rawOut.read(2), -2);
        expectEq("raw_mod_pos_neg", rawOut.read(3), 1);
        expectEq("raw_div_neg_neg", rawOut.read(4), 2);
        expectEq("raw_mod_neg_neg", rawOut.read(5), -1);
        expectEq("raw_div_pos_pos", rawOut.read(6), 2);
        expectEq("raw_mod_pos_pos", rawOut.read(7), 1);

        var fnsOut = new Tensor<U32>(ctx, [7]);
        var fnsKernel = Kernel.build(ctx, macro (out:Tensor<U32>, mask:U32) -> {
          out[0] = SpecialOps.fnsU32(mask, 0, 1);
          out[1] = SpecialOps.fnsU32(mask, 2, 1);
          out[2] = SpecialOps.fnsU32(mask, 0, 2);
          out[3] = SpecialOps.fnsU32(mask, 4, -1);
          out[4] = SpecialOps.fnsU32(mask, 4, -2);
          out[5] = SpecialOps.fnsU32(mask, 6, -1);
          out[6] = SpecialOps.fnsU32(mask, 0, -1);
        });
        kernels.push(fnsKernel);
        fnsKernel.launch(fnsOut, i64(0x2a));
        ctx.sync();
        expectInt64("fns_forward_base0", fnsOut.read(0), i64(1));
        expectInt64("fns_forward_base2", fnsOut.read(1), i64(3));
        expectInt64("fns_forward_second", fnsOut.read(2), i64(3));
        expectInt64("fns_backward_base4", fnsOut.read(3), i64(3));
        expectInt64("fns_backward_second", fnsOut.read(4), i64(1));
        expectInt64("fns_backward_base6", fnsOut.read(5), i64(5));
        expectInt64("fns_not_found", fnsOut.read(6), Int64.make(0, -1));

        var frexpMantissaF32 = new Tensor<F32>(ctx, [1]);
        var frexpMantissaF64 = new Tensor<F64>(ctx, [1]);
        var frexpExponent = new Tensor<I32>(ctx, [2]);
        var frexpKernel = Kernel.build(ctx, macro (m32:Tensor<F32>, m64:Tensor<F64>, exponent:Tensor<I32>) -> {
          var parts32 = SpecialOps.frexpF32(6.5);
          var parts64 = SpecialOps.frexpF64(0.75);
          m32[0] = parts32.significand;
          exponent[0] = parts32.exponent;
          m64[0] = parts64.significand;
          exponent[1] = parts64.exponent;
        });
        kernels.push(frexpKernel);
        frexpKernel.launch(frexpMantissaF32, frexpMantissaF64, frexpExponent);
        ctx.sync();
        expectFloat("frexp_f32_significand", frexpMantissaF32.read(0), 0.8125);
        expectEq("frexp_f32_exponent", frexpExponent.read(0), 3);
        expectFloat("frexp_f64_significand", frexpMantissaF64.read(0), 0.75);
        expectEq("frexp_f64_exponent", frexpExponent.read(1), 0);

        var volatileInput = new Tensor<I32>(ctx, [1]);
        var volatileOut = new Tensor<I32>(ctx, [1]);
        volatileInput.write(0, 123);
        var volatileKernel = Kernel.build(ctx, macro (input:Tensor<I32>, out:Tensor<I32>) -> {
          out[0] = SpecialOps.volatileLoad(input[0]);
        });
        kernels.push(volatileKernel);
        volatileKernel.launch(volatileInput, volatileOut);
        ctx.sync();
        expectEq("volatile_load_runtime", volatileOut.read(0), 123);

        var randnF32A = new Tensor<F32>(ctx, [2]);
        var randnF32B = new Tensor<F32>(ctx, [2]);
        var randnF64A = new Tensor<F64>(ctx, [1]);
        var randnF64B = new Tensor<F64>(ctx, [1]);
        var randnKernel = Kernel.build(ctx, macro (out32:Tensor<F32>, out64:Tensor<F64>) -> {
          out32[0] = SpecialOps.randnF32();
          out32[1] = SpecialOps.randnF32();
          out64[0] = SpecialOps.randnF64();
        });
        kernels.push(randnKernel);
        ctx.setRandomSeed(2468);
        randnKernel.launch(randnF32A, randnF64A);
        ctx.sync();
        ctx.setRandomSeed(2468);
        randnKernel.launch(randnF32B, randnF64B);
        ctx.sync();
        expectFloat("randn_f32_deterministic_0", randnF32A.read(0), randnF32B.read(0), 0.0);
        expectFloat("randn_f32_deterministic_1", randnF32A.read(1), randnF32B.read(1), 0.0);
        expectFloat("randn_f64_deterministic", randnF64A.read(0), randnF64B.read(0), 0.0);
        if (Math.isNaN(randnF32A.read(0)) || Math.isNaN(randnF32A.read(1)) || Math.isNaN(randnF64A.read(0))) throw "randn produced NaN";
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernels(kernels);
        throw e;
      }
      TestRuntimeSupport.closeKernels(kernels);
    });
  }
}
