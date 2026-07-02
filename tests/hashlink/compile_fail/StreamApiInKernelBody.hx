// EXPECT_ERROR: Unsupported Quadrants HashLink function call autoStream
import quadrants.Context;
import quadrants.Graph;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.I32;

class StreamApiInKernelBody {
  static function main():Void {
    var ctx:Context = null;
    Kernel.build(ctx, macro (out:Tensor<I32>) -> {
      var stream = Graph.autoStream();
      out[0] = 1;
    });
  }
}
