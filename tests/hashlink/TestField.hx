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

      var denseSource = new Tensor<I32>(ctx, [4]);
      denseSource.fromArray([5, 6, 7, 8]);
      x.fromTensor(denseSource);
      if (x.snodeId < 0) throw "field_from_tensor_keeps_snode";
      expectEq("field_from_tensor_dense_copy", x.read(2), 7);

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
      var yGrad = y.grad;
      if (yGrad.snodeId < 0) throw "field_sparse_grad_snode_id";
      yGrad.write(0, 9);
      expectEq("field_sparse_grad_host", yGrad.read(0), 9);
      ctx.root.destroy();

      var flag = new Field<U1>(ctx);
      ctx.root.dynamic_(Axis.i, 2).place(flag);
      if (flag.snodeId < 0) throw "field_dynamic_snode_id";
      flag.write(0, true);
      if (!flag.read(0)) throw "field_dynamic_u1_host";
      if (flag.dual.snodeId < 0) throw "field_dynamic_dual_snode_id";
      ctx.root.destroy();

      var shaped = new Field<I32>(ctx, [2]);
      if (shaped.snodeId < 0) throw "field_constructor_snode_id";
      shaped.write(1, 13);
      expectEq("field_constructor_host", shaped.read(1), 13);
      var source = new Tensor<I32>(ctx, [2]);
      source.write(0, 42);
      var alias = new Field<I32>(ctx);
      alias.fromTensor(source);
      expectEq("field_from_tensor_alias", alias.read(0), 42);
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
      expectEq("field_kernel", x.read(0), 9);
      k.close();
      k = null;

      var direct = new Field<I32>(ctx, [4]);
      direct.write(0, 5);
      k = Kernel.build(ctx, macro (field:Field<I32>) -> {
        field[0] = field[0] + 2;
      });
      k.launch(direct);
      ctx.sync();
      expectEq("field_direct_snode_kernel", direct.read(0), 7);
      k.close();
      k = null;
      k = Kernel.build(ctx, macro (field:Field<I32>, out:Tensor<I32>) -> {
        out[0] = field.append(0, 1);
      });
      expectThrows("field_dense_append_rejected", "Field kernel argument rank mismatch", function() {
        k.launch(direct, denseSource);
      });
      k.close();
      k = null;


      var appended = new Field<I32>(ctx);
      ctx.root.dense(Axis.i, 2).dynamic_(Axis.j, 4).place(appended);
      var appendOut = new Tensor<I32>(ctx, [4]);
      appendOut.fill(-1);
      k = Kernel.build(ctx, macro (field:Field<I32>, out:Tensor<I32>) -> {
        out[0] = field.append(0, 7);
        out[1] = field.append(0, 11);
        out[2] = field.length(0);
      });
      k.launch(appended, appendOut);
      ctx.sync();
      expectEq("field_append_first_index", appendOut.read(0), 0);
      expectEq("field_append_second_index", appendOut.read(1), 1);
      expectEq("field_append_length", appendOut.read(2), 2);
      expectEq("field_append_value0", appended.read(0), 7);
      expectEq("field_append_value1", appended.read(1), 11);
      k.close();
      k = null;
      ctx.root.destroy();

      var active = new Field<I32>(ctx);
      ctx.root.bitmasked(Axis.i, 4).place(active);
      var activeOut = new Tensor<I32>(ctx, [3]);
      activeOut.fill(-1);
      k = Kernel.build(ctx, macro (field:Field<I32>, out:Tensor<I32>) -> {
        out[0] = field.isActive(1) ? 1 : 0;
        field.activate(1);
        out[1] = field.isActive(1) ? 1 : 0;
        field[1] = 23;
        field.deactivate(1);
        out[2] = field.isActive(1) ? 1 : 0;
      });
      k.launch(active, activeOut);
      ctx.sync();
      expectEq("field_active_initial", activeOut.read(0), 0);
      expectEq("field_active_after_activate", activeOut.read(1), 1);
      expectEq("field_active_after_deactivate", activeOut.read(2), 0);
      k.close();
      k = null;
      ctx.root.destroy();
      denseSource.close();
      source.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (k != null) k.close();
      ctx.close();
      throw e;
    }
  }
}
