import quadrants.Context;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.Mat2;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Vec2;
import quadrants.packed.PackedHelpers;
import quadrants.packed.PackedMatrixField;
import quadrants.packed.PackedMatrixTensor;
import quadrants.packed.PackedStructTensor;
import quadrants.packed.PackedVectorField;
import quadrants.packed.PackedVectorTensor;
import quadrants.packed.StructOfArraysField;

class TestPackedCompoundRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function testHostPacking(ctx:Context):Void {
    var vectors = PackedVectorTensor.i32(ctx, 2, 2);
    vectors.write(0, Vec2.i32(3, 4));
    vectors.writeComponent(1, 0, 7);
    vectors.writeComponent(1, 1, 8);
    expectEq("packed_vector_host_x", vectors.read(0)[0], 3);
    expectEq("packed_vector_host_y", vectors.read(1)[1], 8);

    var vectorField = PackedVectorField.i32(ctx, 1, 2);
    vectorField.write(0, Vec2.i32(5, 6));
    expectEq("packed_vector_field_host", vectorField.readComponent(0, 1), 6);

    var matrices = PackedMatrixTensor.i32(ctx, 1, 2, 2);
    matrices.write(0, Mat2.i32(1, 2, 3, 4));
    expectEq("packed_matrix_tensor_host", matrices.readElement(0, 1, 0), 3);

    var matrixField = PackedMatrixField.i32(ctx, 1, 2, 2);
    matrixField.write(0, Mat2.i32(9, 8, 7, 6));
    expectEq("packed_matrix_field_host", matrixField.read(0).get(1, 1), 6);

    var memberI = new Tensor<I32>(ctx, [2]);
    var memberJ = new Tensor<I32>(ctx, [2]);
    var packedStruct = new PackedStructTensor()
      .add("i", memberI)
      .add("j", memberJ);
    packedStruct.write("i", 0, 11);
    packedStruct.write("j", 1, 12);
    expectEq("packed_struct_member_i", packedStruct.read("i", 0), 11);
    expectEq("packed_struct_member_j", packedStruct.read("j", 1), 12);

    var fieldI = new Field<I32>(ctx, [2]);
    var fieldJ = new Field<I32>(ctx, [2]);
    var soa = new StructOfArraysField()
      .add("i", fieldI)
      .add("j", fieldJ);
    soa.write("i", 0, 13);
    soa.write("j", 1, 14);
    expectEq("soa_field_member_i", soa.read("i", 0), 13);
    expectEq("soa_field_member_j", soa.read("j", 1), 14);

    vectors.close();
    vectorField.close();
    matrices.close();
    matrixField.close();
    packedStruct.close();
    soa.close();
  }

  static function testKernelHelpers(ctx:Context):Void {
    var vectors = PackedVectorTensor.i32(ctx, 1, 2);
    var out = PackedVectorTensor.i32(ctx, 1, 2);
    var matrices = PackedMatrixTensor.i32(ctx, 1, 2, 2);
    var matrixOut = new Tensor<I32>(ctx, [1]);
    var member = new Tensor<I32>(ctx, [1]);
    var kernel:Kernel = null;
    try {
      vectors.write(0, Vec2.i32(2, 5));
      matrices.write(0, Mat2.i32(1, 2, 3, 4));
      member.write(0, 10);
      kernel = Kernel.build(ctx, macro (vecStorage:Tensor<I32>, outStorage:Tensor<I32>, matStorage:Tensor<I32>, member:Tensor<I32>, matrixOut:Tensor<I32>) -> {
        var v = PackedHelpers.readVec2I32(vecStorage, 0);
        var shifted = Vec2.i32(v[0] + 1, v[1] + 2);
        PackedHelpers.writeVec2I32(outStorage, 0, shifted);
        var m = PackedHelpers.readMat2I32(matStorage, 0);
        matrixOut[0] = m[0] + m[3] + PackedHelpers.readMemberI32(member, 0);
        PackedHelpers.writeMemberI32(member, 0, matrixOut[0] + 1);
      }, {helpers: [PackedHelpers]});
      kernel.launch(vectors.storage, out.storage, matrices.storage, member, matrixOut);
      ctx.sync();
      expectEq("packed_kernel_vec_x", out.readComponent(0, 0), 3);
      expectEq("packed_kernel_vec_y", out.readComponent(0, 1), 7);
      expectEq("packed_kernel_matrix", matrixOut.read(0), 15);
      expectEq("packed_kernel_member", member.read(0), 16);
    } catch (e:Dynamic) {
      if (kernel != null) kernel.close();
      vectors.close();
      out.close();
      matrices.close();
      matrixOut.close();
      member.close();
      throw e;
    }
    if (kernel != null) kernel.close();
    vectors.close();
    out.close();
    matrices.close();
    matrixOut.close();
    member.close();
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testHostPacking(ctx);
      testKernelHelpers(ctx);
    });
  }
}
