package descriptor;

import quadrants.Context;
import quadrants.Diagnostics;
import quadrants.Kernel;
import quadrants.Spec;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.descriptor.Descriptor;

class DescriptorGoldenSnapshot {
  static inline var GOLDEN_PATH = "tests/hashlink/descriptor/golden/primitive_spec.qdhl.json";

  static function joinInts(values:Array<Int>):String {
    return values.join(",");
  }

  static function normalize(kernel:Kernel):String {
    var dump:Dynamic = Diagnostics.descriptorDump(kernel);
    var meta = Descriptor.fromKernel(kernel);
    var sectionKinds = [for (section in (Reflect.field(dump, "sections") : Array<Dynamic>)) (Reflect.field(section, "kind") : Int)];
    var args = [for (arg in meta.args) '"${arg.path}:${arg.argKind}:${arg.kind}"'];
    var resources = [for (resource in meta.resources) '"${resource.path}:${resource.kind}"'];
    var specs = [for (spec in meta.templates) '"${spec.path}:${spec.type}"'];
    return '{"version":${dump.version},"sectionKinds":[${joinInts(sectionKinds)}],"args":[${args.join(",")}],"resources":[${resources.join(",")}],"specs":[${specs.join(",")}]}';
  }

  public static function run():Void {
    var ctx:Context = null;
    try {
      ctx = Context.create({arch: Arch.Cpu});
      var kernel = Kernel.build(ctx, macro (x:Tensor<I32>, n:Spec<Int>) -> {
        x[0] = n;
      }, {name: "descriptor_golden_primitive_spec"});
      var got = normalize(kernel);
      var expected = StringTools.trim(sys.io.File.getContent(GOLDEN_PATH));
      if (got != expected) {
        throw 'descriptor golden mismatch\nexpected: ${expected}\nactual:   ${got}';
      }
      kernel.close();
      ctx.close();
    } catch (e:Dynamic) {
      if (ctx != null) {
        try ctx.close() catch (_:Dynamic) {}
      }
      throw e;
    }
  }
}
