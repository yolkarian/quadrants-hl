// EXPECT_ERROR: StructTensor/StructField element type PlainParticle must use @:build(quadrants.macro.QdStruct.build())
import quadrants.Context;
import quadrants.StructTensor;
import quadrants.Types.Arch;

class PlainParticle {
  public var id:Int;
  public function new() {}
}

class StructTensorNonQdStruct {
  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu});
    var particles:StructTensor<PlainParticle> = StructTensor.alloc(ctx, [1]);
  }
}
