import quadrants.Axis;
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Grouped;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Field;
import quadrants.Types.I16;
import quadrants.Types.I32;
import quadrants.Types.U1;

class TestField {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
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

  public static function run():Void {
    var ctx = new Context(Arch.Cpu);
    var k:Kernel = null;
    try {
      var x:Field<I32> = new Field<I32>(ctx);
      ctx.root.dense(Axis.i, 4).place(x);
      if (x.snodeId < 0) throw "field_dense_snode_id";
      x.write(0, 3);
      expectEq("field_host_write", x.read(0), 3);
      var tensor:Tensor<I32> = x.toTensor();
      expectEq("field_to_tensor_typed", tensor.read(0), 3);
      x.grad.write(0, 9);
      expectEq("field_grad_host", x.grad.read(0), 9);
      x.lazyDual().write(0, 11);
      expectEq("field_dual_host", x.dual.read(0), 11);
      ctx.root.destroy();
      var y = new Field<I16>(ctx);
      ctx.root.pointer(Axis.i, 2).bitmasked(Axis.j, 2).place(y);
      if (y.snodeId < 0) throw "field_sparse_snode_id";
      y.write(0, 7);
      expectEq("field_pointer_bitmasked_host", y.read(0), 7);
      ctx.root.destroy();
      var flag = new Field<U1>(ctx);
      ctx.root.dynamic_(Axis.i, 2).place(flag);
      if (flag.snodeId < 0) throw "field_dynamic_snode_id";
      flag.write(0, true);
      if (!flag.read(0)) throw "field_dynamic_u1_host";
      ctx.root.destroy();
      var shaped = new Field<I32>(ctx, [2]);
      if (shaped.snodeId < 0) throw "field_constructor_snode_id";
      shaped.write(1, 13);
      expectEq("field_constructor_host", shaped.read(1), 13);
      var source = new Tensor<I32>(ctx, [2]);
      source.write(0, 42);
      var alias = new Field<I32>(ctx);
      alias.fromTensor(source);
      expectEq("field_from_tensor", alias.read(0), 42);
      alias.close();
      expectEq("field_close_keeps_borrowed_tensor", source.read(0), 42);
      expectThrows("field_closed_access", "closed", function() {
        alias.read(0);
      });
      source.close();

      k = Kernel.build(ctx, macro (x:Field<I32>, n:Int) -> {
        for (i in 0...n) {
          x[i] = x[i] + 2;
        }
        for (i in x) {
          x[i] = x[i] + 1;
        }
        for (i in Grouped.of(x)) {
          x[i] = x[i] + 1;
        }
      });
      k.launch(x, 4);
      ctx.sync();
      expectEq("field_kernel", x.read(0), 7);
      k.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
