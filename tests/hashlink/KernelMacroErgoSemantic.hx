import quadrants.Context;
import quadrants.Kernel;
import quadrants.Static;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.Vec2;
import quadrants.Vec3;

class KernelMacroErgoSemantic {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw 'KernelMacroErgoSemantic ${name} failed: got ${got}, expected ${expected}';
    }
  }

  static function testSwizzle(ctx:Context):Void {
    var out = new Tensor<I32>(ctx, [8]);
    var k = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var v = Vec3.i32(1, 2, 3);
      var s = v.zx;
      out[0] = s[0];
      out[1] = s[1];
      var w = Vec3.i32(10, 20, 30);
      w.xz = Vec2.i32(7, 9);
      out[2] = w[0];
      out[3] = w[1];
      out[4] = w[2];
      var p = Vec2.i32(4, 5);
      p.xy = p.yx;
      out[5] = p[0];
      out[6] = p[1];
      var rgb = Vec3.i32(6, 7, 8);
      var br = rgb.br;
      out[7] = br[0];
    });
    k.launch(out);
    ctx.sync();
    var values = out.toArray();
    expectEq("swizzle_read_z", values[0], 3);
    expectEq("swizzle_read_x", values[1], 1);
    expectEq("swizzle_write_x", values[2], 7);
    expectEq("swizzle_keep_y", values[3], 20);
    expectEq("swizzle_write_z", values[4], 9);
    expectEq("swizzle_swap_x", values[5], 5);
    expectEq("swizzle_swap_y", values[6], 4);
    expectEq("swizzle_rgba_read", values[7], 8);
    out.close();
  }

  static function testSwitch(ctx:Context):Void {
    var input = new Tensor<I32>(ctx, [5]);
    var out = new Tensor<I32>(ctx, [5]);
    input.fromArray([0, 1, 2, 3, 9]);
    var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
      for (i in 0...5) {
        switch (a[i]) {
          case 0:
            out[i] = 100;
          case 1, 2:
            out[i] = 200;
          case 3:
            out[i] = 300;
          default:
            out[i] = -1;
        }
      }
    });
    k.launch(input, out);
    ctx.sync();
    var values = out.toArray();
    expectEq("switch_case0", values[0], 100);
    expectEq("switch_case1", values[1], 200);
    expectEq("switch_case2", values[2], 200);
    expectEq("switch_case3", values[3], 300);
    expectEq("switch_default", values[4], -1);
    input.close();
    out.close();
  }

  static function testStaticValues(ctx:Context):Void {
    var out = new Tensor<I32>(ctx, [1]);
    var k = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      for (v in Static.values([1, 4, 9])) {
        out[0] += v;
      }
    });
    k.launch(out);
    ctx.sync();
    expectEq("static_values_sum", out.toArray()[0], 14);
    out.close();
  }

  static function testBoundaryClamp(ctx:Context):Void {
    var input = new Tensor<I32>(ctx, [4]);
    var out = new Tensor<I32>(ctx, [4]);
    input.fromArray([1, 2, 3, 4]);
    var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
      for (i in 0...4) {
        out[i] = a[i - 2] + a[i + 2];
      }
    }, {boundaryClamp: ["a"]});
    k.launch(input, out);
    ctx.sync();
    var values = out.toArray();
    expectEq("clamp_low", values[0], 1 + 3);
    expectEq("clamp_mid1", values[1], 1 + 4);
    expectEq("clamp_mid2", values[2], 1 + 4);
    expectEq("clamp_high", values[3], 2 + 4);
    input.close();
    out.close();
  }

  public static function run():Void {
    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true});
    try {
      testSwizzle(ctx);
      testSwitch(ctx);
      testStaticValues(ctx);
      testBoundaryClamp(ctx);
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
    ctx.close();
  }

  static function main():Void {
    run();
    Sys.println("kernel macro ergo semantic ok");
  }
}
