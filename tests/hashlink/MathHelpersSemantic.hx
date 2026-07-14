import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.math.ComplexF32;
import quadrants.math.ComplexF64;
import quadrants.math.MathF32;
import quadrants.math.MathF64;

class MathHelpersSemantic {
  static function expectNear(name:String, got:Float, expected:Float, epsilon:Float):Void {
    if (Math.abs(got - expected) > epsilon) {
      throw 'MathHelpersSemantic ${name} failed: got ${got}, expected ${expected}';
    }
  }

  public static function run(ctx:Context):Void {
    var out32 = new Tensor<F32>(ctx, [46]);
    var out64 = new Tensor<F64>(ctx, [46]);
    var kernel = Kernel.build(ctx, macro (out32:Tensor<F32>, out64:Tensor<F64>) -> {
      var a32 = quadrants.Vec4.f32(1.0, 2.0, 3.0, 4.0);
      var b32 = quadrants.Vec4.f32(4.0, 3.0, 2.0, 1.0);
      out32[0] = MathF32.mixF32(1.0, 2.0, 0.5);
      out32[1] = MathF32.clampF32(3.0, 0.0, 2.0);
      out32[2] = MathF32.stepF32(2.0, 3.0);
      out32[3] = MathF32.fractF32(3.5);
      out32[4] = MathF32.smoothstepF32(0.0, 1.0, 0.5);
      out32[5] = MathF32.signF32(-2.0);
      out32[6] = MathF32.log2F32(8.0);
      out32[7] = MathF32.degreesF32(1.0);
      out32[8] = MathF32.radiansF32(180.0);
      out32[9] = MathF32.modF32(5.0, 3.0);
      out32[10] = MathF32.dot2F32(a32, b32);
      out32[11] = MathF32.dot3F32(a32, b32);
      out32[12] = MathF32.dot4F32(a32, b32);
      out32[13] = MathF32.length2F32(a32);
      out32[14] = MathF32.length3F32(a32);
      out32[15] = MathF32.length4F32(a32);
      out32[16] = MathF32.distance2F32(a32, b32);
      out32[17] = MathF32.distance3F32(a32, b32);
      out32[18] = MathF32.distance4F32(a32, b32);
      var n232 = MathF32.normalize2F32(a32); out32[19] = n232[0];
      var n332 = MathF32.normalize3F32(a32); out32[20] = n332[0];
      var n432 = MathF32.normalize4F32(a32); out32[21] = n432[0];
      var rf232 = MathF32.reflect2F32(a32, b32); out32[22] = rf232[0];
      var rf332 = MathF32.reflect3F32(a32, b32); out32[23] = rf332[0];
      var rf432 = MathF32.reflect4F32(a32, b32); out32[24] = rf432[0];
      var rr232 = MathF32.refract2F32(a32, b32, 0.5); out32[25] = rr232[0];
      var rr332 = MathF32.refract3F32(a32, b32, 0.5); out32[26] = rr332[0];
      var rr432 = MathF32.refract4F32(a32, b32, 0.5); out32[27] = rr432[0];
      var cr32 = MathF32.cross3F32(a32, b32); out32[28] = cr32[0];
      var vd32 = MathF32.vdirF32(0.5); out32[29] = vd32[0];
      var tr32 = MathF32.translateF32(1.0, 2.0, 3.0); out32[30] = tr32.get(0, 3);
      var sc32 = MathF32.scaleF32(1.0, 2.0, 3.0); out32[31] = sc32.get(2, 2);
      var r232 = MathF32.rotation2dF32(0.5); out32[32] = r232.get(0, 0);
      var ra32 = MathF32.rotByAxisF32(a32, 0.5); out32[33] = ra32.get(0, 0);
      var ry32 = MathF32.rotYawPitchRollF32(0.1, 0.2, 0.3); out32[34] = ry32.get(0, 0);
      var r332 = MathF32.rotation3dF32(0.1, 0.2, 0.3); out32[35] = r332.get(0, 0);
      var z132 = quadrants.Vec2.f32(1.0, 2.0); var z232 = quadrants.Vec2.f32(3.0, 4.0);
      var zm32 = ComplexF32.cmulF32(z132, z232); out32[36] = zm32[0];
      var zc32 = ComplexF32.cconjF32(z132); out32[37] = zc32[0];
      var zd32 = ComplexF32.cdivF32(z132, z232); out32[38] = zd32[0];
      var zs32 = ComplexF32.csqrtF32(z132); out32[39] = zs32[0];
      var zi32 = ComplexF32.cinvF32(z132); out32[40] = zi32[0];
      var zp32 = ComplexF32.cpowF32(z132, 3); out32[41] = zp32[0];
      var ze32 = ComplexF32.cexpF32(z132); out32[42] = ze32[0];
      var zl32 = ComplexF32.clogF32(z132); out32[43] = zl32[0];
      out32[44] = MathF32.mixF32(0.0, 10.0, 0.25) + (1.0 : F32);
      out32[45] = MathF32.smoothstepF32(0.0, 1.0, 0.5) + (1.0 : F32);

      var a64 = quadrants.Vec4.f64(1.0, 2.0, 3.0, 4.0);
      var b64 = quadrants.Vec4.f64(4.0, 3.0, 2.0, 1.0);
      out64[0] = MathF64.mixF64(1.0, 2.0, 0.5);
      out64[1] = MathF64.clampF64(3.0, 0.0, 2.0);
      out64[2] = MathF64.stepF64(2.0, 3.0);
      out64[3] = MathF64.fractF64(3.5);
      out64[4] = MathF64.smoothstepF64(0.0, 1.0, 0.5);
      out64[5] = MathF64.signF64(-2.0);
      out64[6] = MathF64.log2F64(8.0);
      out64[7] = MathF64.degreesF64(1.0);
      out64[8] = MathF64.radiansF64(180.0);
      out64[9] = MathF64.modF64(5.0, 3.0);
      out64[10] = MathF64.dot2F64(a64, b64);
      out64[11] = MathF64.dot3F64(a64, b64);
      out64[12] = MathF64.dot4F64(a64, b64);
      out64[13] = MathF64.length2F64(a64);
      out64[14] = MathF64.length3F64(a64);
      out64[15] = MathF64.length4F64(a64);
      out64[16] = MathF64.distance2F64(a64, b64);
      out64[17] = MathF64.distance3F64(a64, b64);
      out64[18] = MathF64.distance4F64(a64, b64);
      var n264 = MathF64.normalize2F64(a64); out64[19] = n264[0];
      var n364 = MathF64.normalize3F64(a64); out64[20] = n364[0];
      var n464 = MathF64.normalize4F64(a64); out64[21] = n464[0];
      var rf264 = MathF64.reflect2F64(a64, b64); out64[22] = rf264[0];
      var rf364 = MathF64.reflect3F64(a64, b64); out64[23] = rf364[0];
      var rf464 = MathF64.reflect4F64(a64, b64); out64[24] = rf464[0];
      var rr264 = MathF64.refract2F64(a64, b64, 0.5); out64[25] = rr264[0];
      var rr364 = MathF64.refract3F64(a64, b64, 0.5); out64[26] = rr364[0];
      var rr464 = MathF64.refract4F64(a64, b64, 0.5); out64[27] = rr464[0];
      var cr64 = MathF64.cross3F64(a64, b64); out64[28] = cr64[0];
      var vd64 = MathF64.vdirF64(0.5); out64[29] = vd64[0];
      var tr64 = MathF64.translateF64(1.0, 2.0, 3.0); out64[30] = tr64.get(0, 3);
      var sc64 = MathF64.scaleF64(1.0, 2.0, 3.0); out64[31] = sc64.get(2, 2);
      var r264 = MathF64.rotation2dF64(0.5); out64[32] = r264.get(0, 0);
      var ra64 = MathF64.rotByAxisF64(a64, 0.5); out64[33] = ra64.get(0, 0);
      var ry64 = MathF64.rotYawPitchRollF64(0.1, 0.2, 0.3); out64[34] = ry64.get(0, 0);
      var r364 = MathF64.rotation3dF64(0.1, 0.2, 0.3); out64[35] = r364.get(0, 0);
      var z164 = quadrants.Vec2.f64(1.0, 2.0); var z264 = quadrants.Vec2.f64(3.0, 4.0);
      var zm64 = ComplexF64.cmulF64(z164, z264); out64[36] = zm64[0];
      var zc64 = ComplexF64.cconjF64(z164); out64[37] = zc64[0];
      var zd64 = ComplexF64.cdivF64(z164, z264); out64[38] = zd64[0];
      var zs64 = ComplexF64.csqrtF64(z164); out64[39] = zs64[0];
      var zi64 = ComplexF64.cinvF64(z164); out64[40] = zi64[0];
      var zp64 = ComplexF64.cpowF64(z164, 3); out64[41] = zp64[0];
      var ze64 = ComplexF64.cexpF64(z164); out64[42] = ze64[0];
      var zl64 = ComplexF64.clogF64(z164); out64[43] = zl64[0];
      out64[44] = MathF64.mixF64(0.0, 10.0, 0.25) + 1.0;
      out64[45] = MathF64.smoothstepF64(0.0, 1.0, 0.5) + 1.0;
    }, {name: "hashlink_math_helpers_semantic", helpers: [MathF32, MathF64, ComplexF32, ComplexF64]});

    try {
      kernel.launch(out32, out64);
      ctx.sync();
      expectNear("mix_f32", out32.read(0), 1.5, 1.0e-6);
      expectNear("smoothstep_f32", out32.read(4), 0.5, 1.0e-6);
      expectNear("matrix_f32", out32.read(30), 1.0, 1.0e-6);
      expectNear("complex_mul_f32", out32.read(36), -5.0, 1.0e-6);
      expectNear("complex_pow_f32", out32.read(41), -11.0, 1.0e-5);
      expectNear("composed_mix_f32", out32.read(44), 3.5, 1.0e-6);
      expectNear("composed_smoothstep_f32", out32.read(45), 1.5, 1.0e-6);
      expectNear("mix_f64", out64.read(0), 1.5, 1.0e-12);
      expectNear("smoothstep_f64", out64.read(4), 0.5, 1.0e-12);
      expectNear("matrix_f64", out64.read(30), 1.0, 1.0e-12);
      expectNear("complex_mul_f64", out64.read(36), -5.0, 1.0e-12);
      expectNear("complex_pow_f64", out64.read(41), -11.0, 1.0e-12);
      expectNear("composed_mix_f64", out64.read(44), 3.5, 1.0e-12);
      expectNear("composed_smoothstep_f64", out64.read(45), 1.5, 1.0e-12);
    } catch (e:Dynamic) {
      kernel.close();
      out32.close();
      out64.close();
      throw e;
    }
    kernel.close();
    out32.close();
    out64.close();
  }
}
