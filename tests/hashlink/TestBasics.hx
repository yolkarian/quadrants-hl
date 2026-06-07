import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Field;
import quadrants.FieldScalar;
import quadrants.TensorScalar;
import quadrants.Types.I32;

class TestBasics {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [4]);
        k = Kernel.build(ctx, macro (out) -> {
          var acc = 1;
          acc = acc + 2;
          out[0] = acc;
        });
        k.launch(out);
        ctx.sync();
        expectEq("local_assign", out.read(0), 3);
        TestRuntimeSupport.closeKernel(k);
        k = null;

        var scalar = TensorScalar.i32(ctx);
        var scalarField = FieldScalar.i32(ctx);
        scalar.scalarWrite(10);
        scalarField.scalarWrite(0);
        k = Kernel.build(ctx, macro (scalar:Tensor<I32>, scalarField:Field<I32>, out:Tensor<I32>) -> {
          scalar.scalarWrite(scalar.scalarRead() + 1);
          scalarField.scalarWrite(scalar.scalarRead() + 2);
          out[1] = scalarField.scalarRead();
        });
        k.launch(scalar, scalarField, out);
        ctx.sync();
        expectEq("scalar_tensor_kernel", scalar.scalarRead(), 11);
        expectEq("scalar_field_kernel", scalarField.scalarRead(), 13);
        expectEq("scalar_out", out.read(1), 13);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
