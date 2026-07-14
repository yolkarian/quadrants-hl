import quadrants.Context;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.snode.RescaleIndex;
import quadrants.sparse.SparseGrid;

class SparseNodeSemantic {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw 'SparseNodeSemantic ${name} failed: got ${got}, expected ${expected}';
    }
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 1.0e-9) {
      throw 'SparseNodeSemantic ${name} failed: got ${got}, expected ${expected}';
    }
  }

  static function testNegativeOffset(ctx:Context):Void {
    var f = new Field<I32>(ctx, null);
    ctx.root.dense([8], {offset: [-4]}).place(f);
    f.write(0, 100);
    f.write(7, 700);
    expectEq("host_negative_offset_low", f.read(0), 100);
    expectEq("host_negative_offset_high", f.read(7), 700);
    var out = new Tensor<I32>(ctx, [8]);
    var k = Kernel.build(ctx, macro (f:Field<I32>, out:Tensor<I32>) -> {
      for (i in f) {
        out[i + 4] = f[i] + 1;
      }
    });
    k.launch(f, out);
    ctx.sync();
    var values = out.toArray();
    expectEq("kernel_negative_offset_low", values[0], 101);
    expectEq("kernel_negative_offset_high", values[7], 701);
    f.close();
    out.close();
  }

  static function testRescaleIndex():Void {
    var fine = RescaleIndex.map([16, 16], [4, 4], [9, 15]);
    expectEq("rescale_down_x", fine[0], 2);
    expectEq("rescale_down_y", fine[1], 3);
    var coarse = RescaleIndex.map([4, 4], [16, 16], [2, 3]);
    expectEq("rescale_up_x", coarse[0], 8);
    expectEq("rescale_up_y", coarse[1], 12);
    var rejected = false;
    try {
      RescaleIndex.map([10, 10], [3, 3], [1, 1]);
    } catch (e:Dynamic) {
      rejected = true;
    }
    if (!rejected) {
      throw "SparseNodeSemantic rescale_invalid_ratio failed to reject";
    }
  }

  static function testSparseGrid(ctx:Context):Void {
    var grid = SparseGrid.create2(ctx, 8, 8);
    var mass = grid.addF32("mass");
    var id = grid.addI32("id");
    grid.commit();
    expectEq("grid_total", grid.total(), 64);
    expectEq("grid_inactive", grid.activeCount(), 0);

    var writer = Kernel.build(ctx, macro (mass:Field<F32>, id:Field<I32>) -> {
      mass[1][2] = 1.5;
      id[1][2] = 12;
      mass[4][4] = 2.5;
      id[4][4] = 44;
      mass[7][0] = 3.5;
      id[7][0] = 70;
    });
    writer.launch(mass, id);
    ctx.sync();

    expectEq("grid_active_after_writes", grid.activeCount(), 3);
    expectNear("grid_usage", grid.usage(), 3.0 / 64.0);

    var sum = new Tensor<I32>(ctx, [1]);
    var sumKernel = Kernel.build(ctx, macro (id:Field<I32>, out:Tensor<I32>) -> {
      for (I in quadrants.Grouped.of(id, 2)) {
        out[0] += id[I[0]][I[1]];
      }
    });
    sumKernel.launch(id, sum);
    ctx.sync();
    expectEq("grid_sparse_sum", sum.toArray()[0], 12 + 44 + 70);
    sum.close();
    grid.close();
  }

  public static function run():Void {
    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true});
    try {
      testNegativeOffset(ctx);
      testRescaleIndex();
      testSparseGrid(ctx);
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
    ctx.close();
  }

  static function main():Void {
    run();
    Sys.println("sparse node semantic ok");
  }
}
