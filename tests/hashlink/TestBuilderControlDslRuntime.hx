import quadrants.Axis;
import quadrants.Context;
import quadrants.Field;
import quadrants.FieldsBuilder;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.runtime.LoopConfig;
import quadrants.snode.FieldTree;

class TestBuilderControlDslRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectThrows(name:String, contains:String, f:Void->Void):Void {
    try {
      f();
    } catch (e:Dynamic) {
      var message = Std.string(e);
      if (message.indexOf(contains) < 0) {
        throw '${name}: expected error containing ${contains}, got ${message}';
      }
      return;
    }
    throw '${name}: expected error containing ${contains}';
  }

  static function testBuilderPath(ctx:Context):Void {
    var a = new Field<I32>(ctx);
    var b = new Field<I32>(ctx);
    var path = ctx.root.dense(Axis.i, 4).placeMany([cast a, cast b]);
    expectEq("builder_path_rank", path.rank, 1);
    expectEq("builder_path_shape", path.shape[0], 4);
    a.write(0, 3);
    b.write(0, 5);
    expectEq("builder_place_many_a", a.read(0), 3);
    expectEq("builder_place_many_b", b.read(0), 5);

    var c = new Field<I32>(ctx);
    path.place(c);
    c.write(1, 7);
    expectEq("builder_path_place", c.read(1), 7);

    var grad:Field<I32> = cast FieldTree.lazyGrad(a);
    grad.write(0, 9);
    expectEq("builder_lazy_grad", a.grad.read(0), 9);
    ctx.root.destroy();
  }

  static function testFinalizeLifecycle(ctx:Context):Void {
    var builder = new FieldsBuilder(ctx);
    var path = builder.dense(Axis.i, 2).finalize();
    expectThrows("builder_finalized_add", "finalized", function() {
      builder.dense(Axis.j, 2);
    });
    var field = new Field<I32>(ctx);
    path.place(field);
    field.write(1, 4);
    expectEq("builder_finalized_path_place", field.read(1), 4);
    builder.destroy();
    var next = new Field<I32>(ctx);
    builder.dense(Axis.i, 1).place(next);
    next.write(0, 6);
    expectEq("builder_destroy_reopens", next.read(0), 6);
    builder.destroy();
  }

  static function testLoopConfig(ctx:Context):Void {
    var out = new Tensor<I32>(ctx, [4]);
    var kernel:Kernel = null;
    try {
      kernel = Kernel.build(ctx, macro (out:Tensor<I32>) -> {
        LoopConfig.blockDim(4);
        LoopConfig.parallelize(2);
        LoopConfig.serialize();
        for (i in 0...4) {
          out[i] = i * 3;
        }
      });
      kernel.launch(out);
      ctx.sync();
      expectEq("loop_config_0", out.read(0), 0);
      expectEq("loop_config_3", out.read(3), 9);
    } catch (e:Dynamic) {
      if (kernel != null) kernel.close();
      out.close();
      throw e;
    }
    if (kernel != null) kernel.close();
    out.close();
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testBuilderPath(ctx);
      testFinalizeLifecycle(ctx);
      testLoopConfig(ctx);
    });
  }
}
