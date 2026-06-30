// EXPECT_ERROR: Type not found : quadrants.Template
import quadrants.Context;
import quadrants.Template;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.DType;
import quadrants.Types.I32;

class TemplateBuildRemoved {
  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu});
    var k = Template.build(DType.I32, ctx, macro (x:Tensor<I32>) -> {
      x[0] = 1;
    });
  }
}
