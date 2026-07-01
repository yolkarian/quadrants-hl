import quadrants.Context;
import quadrants.Kernel;
import quadrants.QD;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.descriptor.Descriptor;

@:qdFlatten
class DescriptorState {
  public final x:Tensor<I32>;
  @:param public final bias:I32;
  @:template public final n:I32;

  public function new(x:Tensor<I32>, bias:I32, n:I32) {
    this.x = x;
    this.bias = bias;
    this.n = n;
  }
}

class TestDescriptorRuntime {
  static function expectEq(name:String, got:Dynamic, expected:Dynamic):Void {
    if (got != expected) {
      throw '${name}: ${got} != ${expected}';
    }
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) {
      throw '${name}: expected true';
    }
  }

  public static function run():Void {
    var ctx:Context = null;
    try {
      ctx = new Context(Arch.Cpu);
      var plain = Kernel.build(ctx, macro (x:Tensor<I32>, n:I32) -> {
        x[0] = n;
      }, {name: "descriptor_plain"});
      var plainMeta = Descriptor.fromKernel(plain);
      expectEq("descriptor_plain_version", plainMeta.version, 3);
      expectEq("descriptor_plain_kernel_name", plainMeta.kernelName, "descriptor_plain");
      expectEq("descriptor_plain_arg0", plainMeta.args[0].path, "x");
      expectEq("descriptor_plain_arg1_kind", plainMeta.args[1].kind, "scalar");
      plain.close();

      var x = new Tensor<I32>(ctx, [4]);
      var state = new DescriptorState(x, 2, 4);
      var flat = QD.kernel(ctx, macro (state:DescriptorState) -> {
        for (i in 0...state.n) {
          state.x[i] = state.x[i] + state.bias;
        }
      }, {name: "descriptor_flat"});
      var flatKernel = Kernel.fromRaw(flat.raw());
      var flatMeta = Descriptor.fromKernel(flatKernel);
      expectEq("descriptor_flat_kernel_name", flatMeta.kernelName, "descriptor_flat");
      expectEq("descriptor_flat_arg0", flatMeta.args[0].path, "state.x");
      expectEq("descriptor_flat_arg1_role", flatMeta.args[1].role, "runtime");
      expectEq("descriptor_flat_template_path", flatMeta.templates[0].path, "state.n");
      expectTrue("descriptor_flat_capability", flatMeta.capabilities.indexOf("template_constants") >= 0);
      flatKernel.close();

      ctx.close();
    } catch (e:Dynamic) {
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
